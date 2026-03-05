import Foundation

public final class UserDefaultsSettingsStore: SettingsStore {
    private enum Keys {
        static let settings = "morpho.app.settings"
    }

    private struct PersistedSettings: Codable {
        let keyCode: UInt32
        let modifiers: UInt8
        let isHotkeyEnabled: Bool?
        let sourceMode: String
        let sourceLanguageIdentifier: String?
        let targetLanguageIdentifier: String
        let autoSwitchPairFirstLanguageIdentifier: String?
        let autoSwitchPairSecondLanguageIdentifier: String?
        let translationProvider: String?
        let translationAPIKey: String?
        let translationBackend: String?
        let launchAtLoginPreferred: Bool?
        let interfaceLanguageCode: String?
        let translationModelID: String?
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> AppSettings {
        guard
            let data = defaults.data(forKey: Keys.settings),
            let persisted = try? JSONDecoder().decode(PersistedSettings.self, from: data)
        else {
            return .defaultValue
        }

        let provider = resolveProvider(from: persisted)

        let sourceLanguage: LanguageSource
        if persisted.sourceMode == "fixed", let identifier = persisted.sourceLanguageIdentifier {
            sourceLanguage = .fixed(Locale.Language(identifier: identifier))
        } else {
            sourceLanguage = .auto
        }

        let autoSwitchLanguagePair: AutoSwitchLanguagePair?
        if
            let firstIdentifier = persisted.autoSwitchPairFirstLanguageIdentifier,
            let secondIdentifier = persisted.autoSwitchPairSecondLanguageIdentifier
        {
            autoSwitchLanguagePair = AutoSwitchLanguagePair(
                firstLanguage: Locale.Language(identifier: firstIdentifier),
                secondLanguage: Locale.Language(identifier: secondIdentifier)
            )
        } else {
            autoSwitchLanguagePair = nil
        }

        return AppSettings(
            hotkey: HotkeyShortcut(
                keyCode: persisted.keyCode,
                modifiers: HotkeyModifiers(rawValue: persisted.modifiers)
            ),
            isHotkeyEnabled: persisted.isHotkeyEnabled ?? true,
            sourceLanguage: sourceLanguage,
            targetLanguage: Locale.Language(identifier: persisted.targetLanguageIdentifier),
            autoSwitchLanguagePair: autoSwitchLanguagePair,
            translationProvider: provider,
            translationAPIKey: persisted.translationAPIKey ?? "",
            launchAtLoginPreferred: persisted.launchAtLoginPreferred ?? AppSettings.defaultValue.launchAtLoginPreferred,
            interfaceLanguageCode: persisted.interfaceLanguageCode ?? AppSettings.defaultValue.interfaceLanguageCode,
            translationModelID: persisted.translationModelID ?? AppSettings.defaultValue.translationModelID
        )
    }

    public func save(_ settings: AppSettings) {
        let sourceMode: String
        let sourceIdentifier: String?

        switch settings.sourceLanguage {
        case .auto:
            sourceMode = "auto"
            sourceIdentifier = nil
        case .fixed(let language):
            sourceMode = "fixed"
            sourceIdentifier = LanguageIdentifierCodec.persistedIdentifier(for: language)
        }

        let pairFirstIdentifier = settings.autoSwitchLanguagePair.map {
            LanguageIdentifierCodec.persistedIdentifier(for: $0.firstLanguage)
        }
        let pairSecondIdentifier = settings.autoSwitchLanguagePair.map {
            LanguageIdentifierCodec.persistedIdentifier(for: $0.secondLanguage)
        }

        let persisted = PersistedSettings(
            keyCode: settings.hotkey.keyCode,
            modifiers: settings.hotkey.modifiers.rawValue,
            isHotkeyEnabled: settings.isHotkeyEnabled,
            sourceMode: sourceMode,
            sourceLanguageIdentifier: sourceIdentifier,
            targetLanguageIdentifier: LanguageIdentifierCodec.persistedIdentifier(for: settings.targetLanguage),
            autoSwitchPairFirstLanguageIdentifier: pairFirstIdentifier,
            autoSwitchPairSecondLanguageIdentifier: pairSecondIdentifier,
            translationProvider: settings.translationProvider.rawValue,
            translationAPIKey: settings.translationAPIKey,
            translationBackend: nil,
            launchAtLoginPreferred: settings.launchAtLoginPreferred,
            interfaceLanguageCode: settings.interfaceLanguageCode,
            translationModelID: settings.translationModelID
        )

        if let data = try? JSONEncoder().encode(persisted) {
            defaults.set(data, forKey: Keys.settings)
        }
    }

    private func resolveProvider(from persisted: PersistedSettings) -> TranslationProvider {
        if let rawProvider = persisted.translationProvider,
           let provider = TranslationProvider(rawValue: rawProvider) {
            return provider
        }

        if persisted.translationBackend != nil {
            return .siliconFlow
        }

        return AppSettings.defaultValue.translationProvider
    }
}
