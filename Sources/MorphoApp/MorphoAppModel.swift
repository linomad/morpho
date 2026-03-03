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
