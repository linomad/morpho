import Foundation

public enum TranslationWorkflowError: Error, Equatable, Sendable {
    case accessibilityPermissionDenied
    case focusedInputUnavailable
    case secureInputUnsupported
    case unsupportedInputControl
    case noTextToTranslate
    case replacementFailed
    case translationFailed
    case cloudEngineNotImplemented
    case systemTranslatorUnavailable
}
