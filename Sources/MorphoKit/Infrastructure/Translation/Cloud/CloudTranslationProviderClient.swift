import Foundation

public protocol CloudTranslationProviderClient {
    func translate(
        text: String,
        source: LanguageSource,
        target: Locale.Language,
        apiKey: String,
        modelID: String?,
        workMode: WorkMode
    ) async throws -> String
}
