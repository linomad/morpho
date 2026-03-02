import Combine
import Foundation
import MorphoKit

@MainActor
final class MorphoAppModel: ObservableObject {
    @Published private(set) var settings: AppSettings
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
        self.statusCenter = statusCenter
        self.statusReporter = statusReporter
        self.lastStatus = StatusEntry(message: "准备就绪", severity: .info)

        let axGateway = AXTextContextGateway()
        let engineFactory = DefaultTranslationEngineFactory(
            systemEngine: SystemTranslationEngine(),
            cloudEngine: CloudTranslationEnginePlaceholder()
        )

        self.useCase = HandleHotkeyTranslationUseCase(
            permissionChecker: AccessibilityPermissionService(),
            contextProvider: axGateway,
            textReplacer: axGateway,
            settingsStore: settingsStore,
            engineFactory: engineFactory,
            statusSink: statusReporter
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

    func updateBackend(_ backend: TranslationBackend) {
        settings.translationBackend = backend
        persistAndApplySettings()
    }

    func updateHotkeyKeyCode(_ keyCode: UInt32) {
        settings.hotkey = HotkeyShortcut(
            keyCode: keyCode,
            modifiers: settings.hotkey.modifiers
        )
        persistAndApplySettings()
    }

    func setModifier(_ modifier: HotkeyModifiers, enabled: Bool) {
        var modifiers = settings.hotkey.modifiers
        if enabled {
            modifiers.insert(modifier)
        } else {
            modifiers.remove(modifier)
        }

        settings.hotkey = HotkeyShortcut(keyCode: settings.hotkey.keyCode, modifiers: modifiers)
        persistAndApplySettings()
    }

    func isModifierEnabled(_ modifier: HotkeyModifiers) -> Bool {
        settings.hotkey.modifiers.contains(modifier)
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
            return language.minimalIdentifier
        }
    }

    var targetLanguageIdentifier: String {
        settings.targetLanguage.minimalIdentifier
    }

    var hotkeySummary: String {
        var parts: [String] = []
        if settings.hotkey.modifiers.contains(.command) { parts.append("⌘") }
        if settings.hotkey.modifiers.contains(.option) { parts.append("⌥") }
        if settings.hotkey.modifiers.contains(.control) { parts.append("⌃") }
        if settings.hotkey.modifiers.contains(.shift) { parts.append("⇧") }
        parts.append(HotkeyKeyOptions.label(for: settings.hotkey.keyCode))
        return parts.joined()
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
        settingsStore.save(settings)
        registerHotkeyIfPossible()
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
