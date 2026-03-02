import Foundation
import NaturalLanguage
@preconcurrency import Translation

public final class SystemTranslationEngine: TranslationEngine {
    public init() {}

    public func translate(_ text: String, source: LanguageSource, target: Locale.Language) async throws -> String {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else {
            throw TranslationWorkflowError.noTextToTranslate
        }

        if #available(macOS 26.0, *) {
            return try await translateWithInstalledSession(
                normalizedText,
                source: source,
                target: target
            )
        }

        return try await TranslationTaskBridgeHost.shared.translate(
            text: normalizedText,
            source: source,
            target: target
        )
    }

    @available(macOS 26.0, *)
    private func translateWithInstalledSession(
        _ text: String,
        source: LanguageSource,
        target: Locale.Language
    ) async throws -> String {
        guard let resolvedSource = resolveSourceLanguage(for: text, source: source) else {
            throw TranslationWorkflowError.translationFailed
        }

        let session = TranslationSession(installedSource: resolvedSource, target: target)

        do {
            let response = try await session.translate(text)
            return response.targetText
        } catch let error as TranslationError {
            switch error {
            case .unsupportedSourceLanguage,
                 .unsupportedTargetLanguage,
                 .unsupportedLanguagePairing,
                 .notInstalled:
                throw TranslationWorkflowError.systemTranslatorUnavailable
            default:
                throw TranslationWorkflowError.translationFailed
            }
        } catch {
            throw TranslationWorkflowError.translationFailed
        }
    }

    private func resolveSourceLanguage(for text: String, source: LanguageSource) -> Locale.Language? {
        switch source {
        case .fixed(let language):
            return language
        case .auto:
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(text)

            guard let language = recognizer.dominantLanguage else {
                return nil
            }

            return Locale.Language(identifier: language.rawValue)
        }
    }
}
