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
        case .noTextToTranslate:
            return "没有可翻译的文本。"
        case .replacementFailed:
            return "翻译完成，但写回输入框失败。"
        case .translationFailed:
            return "翻译失败，请稍后重试。"
        case .cloudEngineNotImplemented:
            return "云端翻译尚未接入，请先使用系统翻译。"
        case .systemTranslatorUnavailable:
            return "系统翻译当前不可用，请安装语言包后重试。"
        }
    }
}
