import Foundation

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case hotkey
    case language
    case engine
    case history
    case about

    var id: String { rawValue }

    func title(locale: Locale) -> String {
        AppLocalization.string(titleKey, locale: locale)
    }

    private var titleKey: String {
        switch self {
        case .general:
            return "settings.tab.general"
        case .hotkey:
            return "settings.tab.hotkey"
        case .language:
            return "settings.tab.translation"
        case .engine:
            return "settings.tab.engine"
        case .history:
            return "settings.tab.history"
        case .about:
            return "settings.tab.about"
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
