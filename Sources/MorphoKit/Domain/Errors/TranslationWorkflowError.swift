import Foundation

public enum TranslationWorkflowError: Error, Equatable, Sendable {
    case accessibilityPermissionDenied
    case focusedInputUnavailable
    case secureInputUnsupported
    case unsupportedInputControl
    case unableToIdentifyLanguage
    case unsupportedLanguagePairing
    case translationSessionStartupTimeout
    case translationInProgress
    case translationInterrupted
    case noTextToTranslate
    case replacementFailed
    case translationFailed
    case cloudEngineNotImplemented
    case systemTranslatorUnavailable
}
