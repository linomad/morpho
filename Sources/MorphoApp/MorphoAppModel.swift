import Combine
import Foundation
import MorphoKit

@MainActor
final class MorphoAppModel: ObservableObject {
    private static let supportedLanguageIdentifiers = LanguageOptions.all.map(\.id)
    private static let defaultSourceLanguage = Locale.Language(identifier: "en")

    @Published private(set) var settings: AppSettings
    @Published private(set) var apiKey: String
    @Published private(set) var lastStatus: StatusEntry
    @Published private(set) var menuBarIconSystemImage: String
    @Published private(set) var runHistoryEntries: [RunHistoryEntry]
    @Published private(set) var launchAtLoginErrorMessage: String?

    private let settingsStore: SettingsStore
    private let runHistoryStore: RunHistoryStore
    private let statusCenter: StatusCenter
    private let statusReporter: CompositeStatusReporter
    private let useCase: HandleHotkeyTranslationUseCase
    private let hotkeyService: GlobalHotkeyService?
    private let caretLoadingOverlay: CaretLoadingOverlay

    private var cancellables: Set<AnyCancellable> = []
    private var inFlightTranslationTask: Task<Void, Never>?
    private var menuBarIconStateMachine: MenuBarIconStateMachine
    private var menuBarIconAnimationTimer: Timer?
    private var menuBarIconCompletionHoldTask: Task<Void, Never>?

    init() {
        let settingsStore = UserDefaultsSettingsStore()
        let runHistoryStore = FileRunHistoryStore()
        let menuBarIconStateMachine = MenuBarIconStateMachine()
        var initialSettings = settingsStore.load()
        if case .auto = initialSettings.sourceLanguage,
           initialSettings.autoSwitchLanguagePair == nil {
            initialSettings.autoSwitchLanguagePair = AppSettings.makeDefaultAutoSwitchLanguagePair(
                targetLanguage: initialSettings.targetLanguage
            )
        }
        initialSettings.launchAtLoginPreferred = LaunchAtLoginController.isEnabled()
        settingsStore.save(initialSettings)
        let statusCenter = StatusCenter()
        let statusReporter = CompositeStatusReporter(
            reporters: [statusCenter, UserNotificationStatusReporter()]
        )

        self.settingsStore = settingsStore
        self.runHistoryStore = runHistoryStore
        self.settings = initialSettings
        self.apiKey = initialSettings.translationAPIKey
        self.statusCenter = statusCenter
        self.statusReporter = statusReporter
        self.caretLoadingOverlay = CaretLoadingOverlay()
        self.lastStatus = StatusEntry(
            message: AppLocalization.string(
                "status.ready",
                locale: InterfaceLanguageOptions.locale(for: initialSettings.interfaceLanguageCode)
            ),
            severity: .info
        )
        self.menuBarIconSystemImage = menuBarIconStateMachine.renderState.baseSymbol
        self.runHistoryEntries = runHistoryStore.load(limit: 200)
        self.launchAtLoginErrorMessage = nil
        self.menuBarIconStateMachine = menuBarIconStateMachine

        let textGateway = LayeredTextContextGateway()
        let siliconFlowHTTPClient = RetryingCloudHTTPClient(
            wrapped: URLSessionCloudHTTPClient()
        )
        let siliconFlowEngine = CloudTranslationEngine(
            client: SiliconFlowTranslationProviderClient(httpClient: siliconFlowHTTPClient)
        )
        let engineFactory = DefaultTranslationEngineFactory(
            siliconFlowEngine: siliconFlowEngine
        )

        self.useCase = HandleHotkeyTranslationUseCase(
            permissionChecker: AccessibilityPermissionService(),
            contextProvider: textGateway,
            textReplacer: textGateway,
            settingsStore: settingsStore,
            engineFactory: engineFactory,
            statusSink: statusReporter,
            sourceLanguageDetector: NaturalLanguageSourceLanguageDetector(),
            runHistoryStore: runHistoryStore
        )

        do {
            let hotkeyService = try GlobalHotkeyService()
            self.hotkeyService = hotkeyService
        } catch {
            self.hotkeyService = nil
        }

        bindStatus()
        bindHotkey()
        registerHotkeyIfPossible()
    }

    func triggerTranslation() {
        guard inFlightTranslationTask == nil else {
            return
        }

        beginMenuBarIconRunningState()
        caretLoadingOverlay.show()

        inFlightTranslationTask = Task { [weak self] in
            guard let self else {
                return
            }

            defer {
                self.handleTranslationCompletion()
            }

            _ = await self.useCase.execute()
        }
    }

    func updateSourceLanguage(_ identifier: String) {
        let language = Locale.Language(identifier: identifier)

        if autoDetectEnabled {
            settings.autoSwitchLanguagePair = AutoSwitchLanguagePair(
                firstLanguage: language,
                secondLanguage: resolvedTargetLanguage()
            )
        } else {
            settings.sourceLanguage = .fixed(language)
        }

        persistAndApplySettings()
    }

    func updateTargetLanguage(_ identifier: String) {
        let language = Locale.Language(identifier: identifier)
        settings.targetLanguage = language

        if autoDetectEnabled {
            settings.autoSwitchLanguagePair = AutoSwitchLanguagePair(
                firstLanguage: resolvedSourceLanguage(),
                secondLanguage: language
            )
        }

        persistAndApplySettings()
    }

    func setAutoDetectEnabled(_ enabled: Bool) {
        let sourceLanguage = resolvedSourceLanguage()
        let targetLanguage = resolvedTargetLanguage()

        if enabled {
            settings.sourceLanguage = .auto
            settings.autoSwitchLanguagePair = AutoSwitchLanguagePair(
                firstLanguage: sourceLanguage,
                secondLanguage: targetLanguage
            )
        } else {
            settings.sourceLanguage = .fixed(sourceLanguage)
            settings.autoSwitchLanguagePair = nil
        }

        settings.targetLanguage = targetLanguage
        persistAndApplySettings()
    }

    func updateProvider(_ provider: TranslationProvider) {
        settings.translationProvider = provider
        persistAndApplySettings()
    }

    func updateTranslationModelID(_ modelID: String) {
        let trimmed = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.translationModelID = trimmed.isEmpty ? AppSettings.defaultTranslationModelID : trimmed
        persistSettings()
    }

    func updateLaunchAtLoginPreferred(_ preferred: Bool) {
        do {
            try LaunchAtLoginController.setEnabled(preferred)
            settings.launchAtLoginPreferred = LaunchAtLoginController.isEnabled()
            launchAtLoginErrorMessage = nil
            persistSettings()
        } catch {
            settings.launchAtLoginPreferred = LaunchAtLoginController.isEnabled()
            launchAtLoginErrorMessage = AppLocalization.format(
                "settings.general.launch_at_login.error",
                locale: interfaceLocale,
                launchAtLoginErrorReason(for: error)
            )
            persistSettings()
            statusReporter.publish(
                StatusEntry(
                    message: launchAtLoginErrorMessage
                        ?? AppLocalization.string(
                            "settings.general.launch_at_login.error_generic",
                            locale: interfaceLocale
                        ),
                    severity: .error
                )
            )
        }
    }

    func updateInterfaceLanguageCode(_ code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.interfaceLanguageCode = trimmed.isEmpty ? AppSettings.defaultInterfaceLanguageCode : trimmed
        persistSettings()
    }

    func updateAPIKey(_ value: String) {
        apiKey = value
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        apiKey = trimmed
        settings.translationAPIKey = trimmed
        persistSettings()
    }

    func updateHotkeyShortcut(_ shortcut: HotkeyShortcut) {
        settings.hotkey = shortcut
        persistAndApplySettings()
    }

    func setHotkeyEnabled(_ enabled: Bool) {
        settings.isHotkeyEnabled = enabled
        persistAndApplySettings()
    }

    var autoDetectEnabled: Bool {
        if case .auto = settings.sourceLanguage {
            return true
        }
        return false
    }

    var sourceLanguageIdentifier: String {
        LanguageIdentifierCodec.displayIdentifier(
            for: resolvedSourceLanguage(),
            supportedIdentifiers: Self.supportedLanguageIdentifiers
        )
    }

    var targetLanguageIdentifier: String {
        LanguageIdentifierCodec.displayIdentifier(
            for: resolvedTargetLanguage(),
            supportedIdentifiers: Self.supportedLanguageIdentifiers
        )
    }

    var hotkeySummary: String {
        HotkeyShortcutPresentation.summary(for: settings.hotkey)
    }

    var hotkeyEnabled: Bool {
        settings.isHotkeyEnabled
    }

    var launchAtLoginPreferred: Bool {
        settings.launchAtLoginPreferred
    }

    var interfaceLanguageCode: String {
        settings.interfaceLanguageCode
    }

    var translationModelID: String {
        settings.translationModelID
    }

    func refreshRunHistory(limit: Int = 200) {
        runHistoryEntries = runHistoryStore.load(limit: limit)
    }

    func clearRunHistory() {
        runHistoryStore.clear()
        runHistoryEntries = []
    }

    private func resolvedSourceLanguage() -> Locale.Language {
        if let pair = settings.autoSwitchLanguagePair {
            return pair.firstLanguage
        }

        switch settings.sourceLanguage {
        case .auto:
            return Self.defaultSourceLanguage
        case .fixed(let language):
            return language
        }
    }

    private func resolvedTargetLanguage() -> Locale.Language {
        settings.autoSwitchLanguagePair?.secondLanguage ?? settings.targetLanguage
    }

    private func bindStatus() {
        statusCenter.$lastEntry
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entry in
                self?.lastStatus = entry
            }
            .store(in: &cancellables)
    }

    private func bindHotkey() {
        hotkeyService?.onHotkeyPressed = { [weak self] in
            Task { @MainActor in
                self?.triggerTranslation()
            }
        }
    }

    private func persistAndApplySettings() {
        persistSettings()
        registerHotkeyIfPossible()
    }

    private func persistSettings() {
        settingsStore.save(settings)
    }

    private func registerHotkeyIfPossible() {
        if !settings.isHotkeyEnabled {
            hotkeyService?.unregister()
            return
        }

        guard let hotkeyService else {
            statusReporter.publish(
                StatusEntry(
                    message: AppLocalization.string(
                        "status.hotkey.init_failed",
                        locale: interfaceLocale
                    ),
                    severity: .error
                )
            )
            return
        }

        do {
            try hotkeyService.register(settings.hotkey)
        } catch {
            statusReporter.publish(
                StatusEntry(
                    message: AppLocalization.string(
                        "status.hotkey.register_failed",
                        locale: interfaceLocale
                    ),
                    severity: .error
                )
            )
        }
    }

    private var interfaceLocale: Locale {
        InterfaceLanguageOptions.locale(for: settings.interfaceLanguageCode)
    }

    private func launchAtLoginErrorReason(for error: Error) -> String {
        guard let launchError = error as? LaunchAtLoginControllerError else {
            return error.localizedDescription
        }

        switch launchError {
        case .unsupportedSystem:
            return AppLocalization.string(
                "status.launch_at_login.unsupported_system",
                locale: interfaceLocale
            )
        case .registrationFailed(let reason):
            return reason
        }
    }

    private func handleTranslationCompletion() {
        caretLoadingOverlay.hide()
        inFlightTranslationTask = nil
        refreshRunHistory()
        transitionMenuBarIconToCompletionHold()
    }

    private func beginMenuBarIconRunningState() {
        menuBarIconCompletionHoldTask?.cancel()
        menuBarIconCompletionHoldTask = nil
        menuBarIconStateMachine.beginTranslation()
        menuBarIconSystemImage = menuBarIconStateMachine.renderState.baseSymbol
        startMenuBarIconAnimationTimerIfNeeded()
    }

    private func transitionMenuBarIconToCompletionHold() {
        stopMenuBarIconAnimationTimer()
        menuBarIconStateMachine.finishTranslation()
        menuBarIconSystemImage = menuBarIconStateMachine.renderState.baseSymbol
        menuBarIconCompletionHoldTask?.cancel()

        menuBarIconCompletionHoldTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                try await Task.sleep(for: .seconds(MenuBarIconStateMachine.fadeOutDuration))
            } catch {
                return
            }

            guard !Task.isCancelled else {
                return
            }

            self.resetMenuBarIconToIdle()
        }
    }

    private func resetMenuBarIconToIdle() {
        menuBarIconCompletionHoldTask = nil
        menuBarIconSystemImage = menuBarIconStateMachine.renderState.baseSymbol
    }

    private func startMenuBarIconAnimationTimerIfNeeded() {
        stopMenuBarIconAnimationTimer()
        guard menuBarIconStateMachine.isAnimating else {
            return
        }

        let timer = Timer(
            timeInterval: 1.0 / 30.0,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.advanceMenuBarIconAnimation()
            }
        }

        menuBarIconAnimationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopMenuBarIconAnimationTimer() {
        menuBarIconAnimationTimer?.invalidate()
        menuBarIconAnimationTimer = nil
    }

    private func advanceMenuBarIconAnimation() {
        guard inFlightTranslationTask != nil else {
            stopMenuBarIconAnimationTimer()
            return
        }

        menuBarIconStateMachine.animationTick(deltaSeconds: 1.0 / 30.0)
        menuBarIconSystemImage = menuBarIconStateMachine.renderState.baseSymbol
    }
}
