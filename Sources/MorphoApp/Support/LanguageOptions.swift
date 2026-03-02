import Foundation

struct LanguageOption: Identifiable {
    let id: String
    let title: String

    init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

enum LanguageOptions {
    static let all: [LanguageOption] = [
        LanguageOption(id: "en", title: "English"),
        LanguageOption(id: "zh-Hans", title: "简体中文"),
        LanguageOption(id: "zh-Hant", title: "繁體中文"),
        LanguageOption(id: "ja", title: "日本語"),
        LanguageOption(id: "ko", title: "한국어"),
        LanguageOption(id: "fr", title: "Français"),
        LanguageOption(id: "de", title: "Deutsch"),
        LanguageOption(id: "es", title: "Español"),
        LanguageOption(id: "it", title: "Italiano"),
        LanguageOption(id: "pt", title: "Português"),
        LanguageOption(id: "ru", title: "Русский")
    ]

    static func title(for identifier: String) -> String {
        all.first(where: { $0.id == identifier })?.title ?? identifier
    }
}
