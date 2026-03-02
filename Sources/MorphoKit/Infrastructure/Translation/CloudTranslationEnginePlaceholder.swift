import Foundation

public final class CloudTranslationEnginePlaceholder: TranslationEngine {
    public init() {}

    public func translate(_ text: String, source: LanguageSource, target: Locale.Language) async throws -> String {
        throw TranslationWorkflowError.cloudEngineNotImplemented
    }
}
