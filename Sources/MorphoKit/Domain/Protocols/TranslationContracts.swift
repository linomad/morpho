import Foundation

public protocol TextContextProvider {
    func captureFocusedContext() throws -> TextContext
}

public protocol TextReplacer {
    func replace(in context: TextContext, with translatedText: String, mode: ReplacementMode) throws
}

public protocol TranslationEngine {
    func translate(
        _ text: String,
        source: LanguageSource,
        target: Locale.Language,
        apiKey: String?,
        modelID: String?,
        workMode: WorkMode
    ) async throws -> String
}

extension TranslationEngine {
    public func translate(
        _ text: String,
        source: LanguageSource,
        target: Locale.Language,
        apiKey: String?,
        modelID: String?
    ) async throws -> String {
        try await translate(text, source: source, target: target, apiKey: apiKey, modelID: modelID, workMode: .translate)
    }
}

public protocol TranslationEngineFactoryProtocol {
    func makeEngine(for provider: TranslationProvider) -> any TranslationEngine
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

public protocol SourceLanguageDetecting {
    func detectLanguage(for text: String) -> Locale.Language?
}
