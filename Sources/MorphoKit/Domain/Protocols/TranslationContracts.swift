import Foundation

public protocol TextContextProvider {
    func captureFocusedContext() throws -> TextContext
}

public protocol TextReplacer {
    func replace(in context: TextContext, with translatedText: String, mode: ReplacementMode) throws
}

public protocol TranslationEngine {
    func translate(_ text: String, source: LanguageSource, target: Locale.Language) async throws -> String
}

public protocol TranslationEngineFactoryProtocol {
    func makeEngine(for backend: TranslationBackend) -> any TranslationEngine
}

public protocol SettingsStore {
    func load() -> AppSettings
    func save(_ settings: AppSettings)
}

public protocol AccessibilityPermissionChecking {
    func isTrusted(prompt: Bool) -> Bool
}

public protocol StatusReporting {
    func publish(_ entry: StatusEntry)
}
