import Foundation

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case hotkey
    case language
    case engine
    case history
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return "通用"
        case .hotkey:
            return "快捷键"
        case .language:
            return "语言"
        case .engine:
            return "翻译引擎"
        case .history:
            return "运行历史"
        case .about:
            return "关于"
        }
    }

    var iconName: String {
        switch self {
        case .general:
            return "slider.horizontal.3"
        case .hotkey:
            return "keyboard"
        case .language:
            return "globe"
        case .engine:
            return "waveform"
        case .history:
            return "clock.arrow.circlepath"
        case .about:
            return "info.circle"
        }
    }
}
