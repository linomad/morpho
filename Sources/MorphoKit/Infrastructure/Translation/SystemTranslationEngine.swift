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
            let resolvedSource = try resolveSourceForInstalledSession(text: normalizedText, source: source)
            if isSameLanguagePair(source: resolvedSource, target: target) {
                return normalizedText
            }

            try await preflightAvailability(source: resolvedSource, target: target)
            return try await translateWithInstalledSession(
                normalizedText,
                source: resolvedSource,
                target: target
            )
        }

        switch source {
        case .fixed(let fixed):
            if isSameLanguagePair(source: fixed, target: target) {
                return normalizedText
            }

            try await preflightAvailability(source: fixed, target: target)
            return try await TranslationTaskBridgeHost.shared.translate(
                text: normalizedText,
                source: fixed,
                target: target
            )

        case .auto:
            try await preflightAvailability(text: normalizedText, target: target)
            return try await TranslationTaskBridgeHost.shared.translate(
                text: normalizedText,
                source: nil,
                target: target
            )
        }
    }

    @available(macOS 26.0, *)
    private func translateWithInstalledSession(
        _ text: String,
        source: Locale.Language,
        target: Locale.Language
    ) async throws -> String {
        let session = TranslationSession(installedSource: source, target: target)

        do {
            try await session.prepareTranslation()
            let response = try await session.translate(text)
            return response.targetText
        } catch let error as TranslationError {
            throw TranslationErrorMapper.map(error)
        } catch is CancellationError {
            throw TranslationWorkflowError.translationInterrupted
        } catch {
            throw TranslationWorkflowError.translationFailed
        }
    }

    private func resolveSourceForInstalledSession(
        text: String,
        source: LanguageSource
    ) throws -> Locale.Language {
        switch source {
        case .fixed(let language):
            return language
        case .auto:
            let recognizer = NLLanguageRecognizer()
            recognizer.processString(text)

            guard let language = recognizer.dominantLanguage else {
                throw TranslationWorkflowError.unableToIdentifyLanguage
            }

            return Locale.Language(identifier: language.rawValue)
        }
    }

    private func preflightAvailability(source: Locale.Language, target: Locale.Language) async throws {
        let availability = LanguageAvailability()
        let status = await availability.status(from: source, to: target)

        switch status {
        case .installed:
            return
        case .supported:
            throw TranslationWorkflowError.systemTranslatorUnavailable
        case .unsupported:
            throw TranslationWorkflowError.unsupportedLanguagePairing
        @unknown default:
            throw TranslationWorkflowError.translationFailed
        }
    }

    private func preflightAvailability(text: String, target: Locale.Language) async throws {
        let availability = LanguageAvailability()

        do {
            let status = try await availability.status(for: text, to: target)
            switch status {
            case .installed:
                return
            case .supported:
                throw TranslationWorkflowError.systemTranslatorUnavailable
            case .unsupported:
                throw TranslationWorkflowError.unsupportedLanguagePairing
            @unknown default:
                throw TranslationWorkflowError.translationFailed
            }
        } catch let error as TranslationError {
            throw TranslationErrorMapper.map(error)
        } catch {
            throw TranslationWorkflowError.translationFailed
        }
    }

    private func isSameLanguagePair(source: Locale.Language, target: Locale.Language) -> Bool {
        source.minimalIdentifier == target.minimalIdentifier
    }
}
