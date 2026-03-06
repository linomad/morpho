import Foundation
import MorphoKit

struct InterfaceLanguageOption: Identifiable, Equatable {
    let id: String
    let titleKey: String

    func title(locale: Locale) -> String {
        AppLocalization.string(titleKey, locale: locale)
    }
}

enum InterfaceLanguageOptions {
    static let all: [InterfaceLanguageOption] = [
        InterfaceLanguageOption(
            id: AppSettings.defaultInterfaceLanguageCode,
            titleKey: "settings.interface_language.option.system"
        ),
        InterfaceLanguageOption(
            id: "zh-Hans",
            titleKey: "settings.interface_language.option.zh_hans"
        ),
        InterfaceLanguageOption(
            id: "en",
            titleKey: "settings.interface_language.option.en"
        )
    ]

    static func normalizedCode(_ code: String) -> String {
        if all.contains(where: { $0.id == code }) {
            return code
        }
        return AppSettings.defaultInterfaceLanguageCode
    }

    static func title(for code: String, locale: Locale) -> String {
        let normalized = normalizedCode(code)
        return all.first(where: { $0.id == normalized })?.title(locale: locale) ?? normalized
    }

    static func locale(for code: String) -> Locale {
        let normalized = normalizedCode(code)
        switch normalized {
        case "en":
            return Locale(identifier: "en")
        case "zh-Hans":
            return Locale(identifier: "zh-Hans")
        default:
            return Locale.current
        }
    }
}
