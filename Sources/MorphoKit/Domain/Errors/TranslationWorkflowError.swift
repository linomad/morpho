import Foundation

public enum TranslationWorkflowError: Error, Equatable, Sendable {
    case accessibilityPermissionDenied
    case focusedInputUnavailable
    case secureInputUnsupported
    case unsupportedInputControl
    case selectionRequiredForCurrentControl
    case unableToIdentifyLanguage
    case unsupportedLanguagePairing
    case translationInterrupted
    case noTextToTranslate
    case replacementFailed
    case translationFailed
    case cloudCredentialMissing
    case cloudAuthenticationFailed
    case cloudRateLimited
    case cloudServiceUnavailable
    case inputTextTooLong(actualCount: Int, maxCount: Int)
}
