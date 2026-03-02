import Foundation

public protocol CloudTranslationProviderClient {
    func translate(
        text: String,
        source: LanguageSource,
        target: Locale.Language,
        apiKey: String
    ) async throws -> String
}
