import Foundation

public struct TranslationErrorDescriptor: Sendable, Equatable {
    public let key: String
    public let args: [String]

    public init(key: String, args: [String] = []) {
        self.key = key
        self.args = args
    }
}

public enum TranslationErrorPresenter {
    public static func descriptor(for error: TranslationWorkflowError) -> TranslationErrorDescriptor {
        switch error {
        case .accessibilityPermissionDenied:
            return TranslationErrorDescriptor(key: "error.accessibility_permission_denied")
        case .focusedInputUnavailable:
            return TranslationErrorDescriptor(key: "error.focused_input_unavailable")
        case .secureInputUnsupported:
            return TranslationErrorDescriptor(key: "error.secure_input_unsupported")
        case .unsupportedInputControl:
            return TranslationErrorDescriptor(key: "error.unsupported_input_control")
        case .selectionRequiredForCurrentControl:
            return TranslationErrorDescriptor(key: "error.selection_required")
        case .unableToIdentifyLanguage:
            return TranslationErrorDescriptor(key: "error.unable_to_identify_language")
        case .unsupportedLanguagePairing:
            return TranslationErrorDescriptor(key: "error.unsupported_language_pair")
        case .translationInterrupted:
            return TranslationErrorDescriptor(key: "error.translation_interrupted")
        case .noTextToTranslate:
            return TranslationErrorDescriptor(key: "error.no_text_to_translate")
        case .replacementFailed:
            return TranslationErrorDescriptor(key: "error.replacement_failed")
        case .translationFailed:
            return TranslationErrorDescriptor(key: "error.translation_failed")
        case .cloudCredentialMissing:
            return TranslationErrorDescriptor(key: "error.cloud.credential_missing")
        case .cloudAuthenticationFailed:
            return TranslationErrorDescriptor(key: "error.cloud.auth_failed")
        case .cloudRateLimited:
            return TranslationErrorDescriptor(key: "error.cloud.rate_limited")
        case .cloudServiceUnavailable:
            return TranslationErrorDescriptor(key: "error.cloud.service_unavailable")
        case .inputTextTooLong(let actual, let limit):
            return TranslationErrorDescriptor(
                key: "error.input_text_too_long",
                args: [String(actual), String(limit)]
            )
        }
    }
}
