import Combine
import Foundation
import MorphoKit

@MainActor
final class MorphoAppModel: ObservableObject {
    private static let supportedLanguageIdentifiers = LanguageOptions.all.map(\.id)
    private static let defaultAutoSwitchPair = AutoSwitchLanguagePair(
        firstLanguage: Locale.Language(identifier: "zh-Hans"),
        secondLanguage: Locale.Language(identifier: "en")
    )

    @Published private(set) var settings: AppSettings
    @Published private(set) var apiKey: String
    @Published private(set) var lastStatus: StatusEntry

    private let settingsStore: SettingsStore
    private let statusCenter: StatusCenter
    private let statusReporter: CompositeStatusReporter
    private let useCase: HandleHotkeyTranslationUseCase
    private let hotkeyService: GlobalHotkeyService?

    private var cancellables: Set<AnyCancellable> = []

    init() {
        let settingsStore = UserDefaultsSettingsStore()
        let initialSettings = settingsStore.load()
        let statusCenter = StatusCenter()
        let statusReporter = CompositeStatusReporter(
            reporters: [statusCenter, UserNotificationStatusReporter()]
        )

        self.settingsStore = settingsStore
        self.settings = initialSettings
        self.apiKey = initialSettings.translationAPIKey
        self.statusCenter = statusCenter
        self.statusReporter = statusReporter
        self.lastStatus = StatusEntry(message: "准备就绪", severity: .info)

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
            sourceLanguageDetector: NaturalLanguageSourceLanguageDetector()
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
        Task {
            _ = await useCase.execute()
        }
    }

    func updateTargetLanguage(_ identifier: String) {
        settings.targetLanguage = Locale.Language(identifier: identifier)
        persistAndApplySettings()
    }

    func updateSourceLanguageMode(isAuto: Bool, fixedLanguageIdentifier: String) {
        if isAuto {
            settings.sourceLanguage = .auto
        } else {
            settings.sourceLanguage = .fixed(Locale.Language(identifier: fixedLanguageIdentifier))
        }
        persistAndApplySettings()
    }

    func updateProvider(_ provider: TranslationProvider) {
        settings.translationProvider = provider
        persistAndApplySettings()
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

    var sourceLanguageIsAuto: Bool {
        if case .auto = settings.sourceLanguage {
            return true
        }
        return false
    }

    var fixedSourceLanguageIdentifier: String {
        switch settings.sourceLanguage {
        case .auto:
            return "en"
        case .fixed(let language):
            return LanguageIdentifierCodec.displayIdentifier(
                for: language,
                supportedIdentifiers: Self.supportedLanguageIdentifiers
            )
        }
    }

    var targetLanguageIdentifier: String {
        LanguageIdentifierCodec.displayIdentifier(
            for: settings.targetLanguage,
            supportedIdentifiers: Self.supportedLanguageIdentifiers
        )
    }

    var autoSwitchLanguagePairEnabled: Bool {
        settings.autoSwitchLanguagePair != nil
    }

    var autoSwitchFirstLanguageIdentifier: String {
        guard let pair = settings.autoSwitchLanguagePair else {
            return LanguageIdentifierCodec.displayIdentifier(
                for: Self.defaultAutoSwitchPair.firstLanguage,
                supportedIdentifiers: Self.supportedLanguageIdentifiers
            )
        }

        return LanguageIdentifierCodec.displayIdentifier(
            for: pair.firstLanguage,
            supportedIdentifiers: Self.supportedLanguageIdentifiers
        )
    }

    var autoSwitchSecondLanguageIdentifier: String {
        guard let pair = settings.autoSwitchLanguagePair else {
            return LanguageIdentifierCodec.displayIdentifier(
                for: Self.defaultAutoSwitchPair.secondLanguage,
                supportedIdentifiers: Self.supportedLanguageIdentifiers
            )
        }

        return LanguageIdentifierCodec.displayIdentifier(
            for: pair.secondLanguage,
            supportedIdentifiers: Self.supportedLanguageIdentifiers
        )
    }

    func setAutoSwitchLanguagePairEnabled(_ enabled: Bool) {
        if enabled {
            if settings.autoSwitchLanguagePair == nil {
                settings.autoSwitchLanguagePair = Self.defaultAutoSwitchPair
            }
        } else {
            settings.autoSwitchLanguagePair = nil
        }

        persistAndApplySettings()
    }

    func updateAutoSwitchLanguagePair(
        firstLanguageIdentifier: String,
        secondLanguageIdentifier: String
    ) {
        let firstLanguage = Locale.Language(identifier: firstLanguageIdentifier)
        let secondLanguage = Locale.Language(identifier: secondLanguageIdentifier)
        guard firstLanguage.minimalIdentifier != secondLanguage.minimalIdentifier else {
            return
        }

        settings.autoSwitchLanguagePair = AutoSwitchLanguagePair(
            firstLanguage: firstLanguage,
            secondLanguage: secondLanguage
        )
        persistAndApplySettings()
    }

    var hotkeySummary: String {
        HotkeyShortcutPresentation.summary(for: settings.hotkey)
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
        guard let hotkeyService else {
            statusReporter.publish(
                StatusEntry(
                    message: "全局快捷键初始化失败。",
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
                    message: "快捷键注册失败，请更换组合键。",
                    severity: .error
                )
            )
        }
    }
}
