import Foundation

public enum TranslationErrorPresenter {
    public static func message(for error: TranslationWorkflowError) -> String {
        switch error {
        case .accessibilityPermissionDenied:
            return "需要辅助功能权限，已为你打开系统设置。"
        case .focusedInputUnavailable:
            return "没有找到可编辑的输入框。"
        case .secureInputUnsupported:
            return "安全输入框不支持翻译。"
        case .unsupportedInputControl:
            return "当前输入控件不支持直接翻译。"
        case .unableToIdentifyLanguage:
            return "无法识别源语言，请在设置中固定源语言后重试。"
        case .unsupportedLanguagePairing:
            return "当前源语言与目标语言组合暂不支持。"
        case .translationInterrupted:
            return "翻译过程被中断，请重试。"
        case .noTextToTranslate:
            return "没有可翻译的文本。"
        case .replacementFailed:
            return "翻译完成，但写回输入框失败。"
        case .translationFailed:
            return "翻译失败，请稍后重试。"
        case .cloudCredentialMissing:
            return "请先在设置中填写 API Key。"
        case .cloudAuthenticationFailed:
            return "API Key 校验失败，请检查后重试。"
        case .cloudRateLimited:
            return "请求过于频繁，请稍后重试。"
        case .cloudServiceUnavailable:
            return "翻译服务暂时不可用，请稍后重试。"
        }
    }
}
