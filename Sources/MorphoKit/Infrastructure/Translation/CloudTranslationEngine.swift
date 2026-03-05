import Foundation

public final class CloudTranslationEngine: TranslationEngine {
    private let client: any CloudTranslationProviderClient

    public init(
        client: any CloudTranslationProviderClient
    ) {
        self.client = client
    }

    public func translate(
        _ text: String,
        source: LanguageSource,
        target: Locale.Language,
        apiKey: String?,
        modelID: String?
    ) async throws -> String {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else {
            throw TranslationWorkflowError.noTextToTranslate
        }

        if case .fixed(let sourceLanguage) = source,
           sourceLanguage.minimalIdentifier == target.minimalIdentifier {
            return normalizedText
        }

        guard let apiKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines),
              !apiKey.isEmpty else {
            throw TranslationWorkflowError.cloudCredentialMissing
        }

        do {
            return try await client.translate(
                text: normalizedText,
                source: source,
                target: target,
                apiKey: apiKey,
                modelID: modelID
            )
        } catch let error as TranslationWorkflowError {
            throw error
        } catch is CancellationError {
            throw TranslationWorkflowError.translationInterrupted
        } catch {
            throw TranslationWorkflowError.translationFailed
        }
    }
}
