import Foundation

public final class UserDefaultsSettingsStore: SettingsStore {
    private enum Keys {
        static let settings = "morpho.app.settings"
    }

    private struct PersistedSettings: Codable {
        let keyCode: UInt32
        let modifiers: UInt8
        let sourceMode: String
        let sourceLanguageIdentifier: String?
        let targetLanguageIdentifier: String
        let translationBackend: String
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> AppSettings {
        guard
            let data = defaults.data(forKey: Keys.settings),
            let persisted = try? JSONDecoder().decode(PersistedSettings.self, from: data),
            let backend = TranslationBackend(rawValue: persisted.translationBackend)
        else {
            return .defaultValue
        }

        let sourceLanguage: LanguageSource
        if persisted.sourceMode == "fixed", let identifier = persisted.sourceLanguageIdentifier {
            sourceLanguage = .fixed(Locale.Language(identifier: identifier))
        } else {
            sourceLanguage = .auto
        }

        return AppSettings(
            hotkey: HotkeyShortcut(
                keyCode: persisted.keyCode,
                modifiers: HotkeyModifiers(rawValue: persisted.modifiers)
            ),
            sourceLanguage: sourceLanguage,
            targetLanguage: Locale.Language(identifier: persisted.targetLanguageIdentifier),
            translationBackend: backend
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
            sourceIdentifier = language.languageCode?.identifier
        }

        let persisted = PersistedSettings(
            keyCode: settings.hotkey.keyCode,
            modifiers: settings.hotkey.modifiers.rawValue,
            sourceMode: sourceMode,
            sourceLanguageIdentifier: sourceIdentifier,
            targetLanguageIdentifier: settings.targetLanguage.minimalIdentifier,
            translationBackend: settings.translationBackend.rawValue
        )

        if let data = try? JSONEncoder().encode(persisted) {
            defaults.set(data, forKey: Keys.settings)
        }
    }
}
