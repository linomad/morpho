import Foundation
@preconcurrency import Translation

enum TranslationErrorMapper {
    static func map(_ error: TranslationError) -> TranslationWorkflowError {
        if #available(macOS 26.0, *), TranslationError.notInstalled ~= error {
            return .systemTranslatorUnavailable
        }

        switch error {
        case .unsupportedSourceLanguage,
             .unsupportedTargetLanguage,
             .unsupportedLanguagePairing:
            return .unsupportedLanguagePairing
        case .unableToIdentifyLanguage:
            return .unableToIdentifyLanguage
        case .nothingToTranslate:
            return .noTextToTranslate
        case .internalError:
            return .translationFailed
        default:
            return .translationFailed
        }
    }
}
