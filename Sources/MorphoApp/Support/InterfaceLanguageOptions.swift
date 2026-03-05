import Foundation
import MorphoKit

struct InterfaceLanguageOption: Identifiable, Equatable {
    let id: String
    let title: String
}

enum InterfaceLanguageOptions {
    static let all: [InterfaceLanguageOption] = [
        InterfaceLanguageOption(id: AppSettings.defaultInterfaceLanguageCode, title: "跟随系统"),
        InterfaceLanguageOption(id: "zh-Hans", title: "简体中文"),
        InterfaceLanguageOption(id: "en", title: "English")
    ]

    static func normalizedCode(_ code: String) -> String {
        if all.contains(where: { $0.id == code }) {
            return code
        }
        return AppSettings.defaultInterfaceLanguageCode
    }

    static func title(for code: String) -> String {
        let normalized = normalizedCode(code)
        return all.first(where: { $0.id == normalized })?.title ?? normalized
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
