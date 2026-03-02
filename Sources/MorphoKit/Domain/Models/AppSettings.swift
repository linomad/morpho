import Foundation

public struct HotkeyModifiers: OptionSet, Equatable, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    public static let command = HotkeyModifiers(rawValue: 1 << 0)
    public static let option = HotkeyModifiers(rawValue: 1 << 1)
    public static let control = HotkeyModifiers(rawValue: 1 << 2)
    public static let shift = HotkeyModifiers(rawValue: 1 << 3)
}

public struct HotkeyShortcut: Equatable, Sendable {
    public let keyCode: UInt32
    public let modifiers: HotkeyModifiers

    public init(keyCode: UInt32, modifiers: HotkeyModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public static let defaultValue = HotkeyShortcut(
        keyCode: 17, // T key
        modifiers: [.option, .shift]
    )
}

public struct AppSettings: Equatable, Sendable {
    public var hotkey: HotkeyShortcut
    public var sourceLanguage: LanguageSource
    public var targetLanguage: Locale.Language
    public var translationProvider: TranslationProvider
    public var translationAPIKey: String

    public init(
        hotkey: HotkeyShortcut,
        sourceLanguage: LanguageSource,
        targetLanguage: Locale.Language,
        translationProvider: TranslationProvider,
        translationAPIKey: String
    ) {
        self.hotkey = hotkey
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.translationProvider = translationProvider
        self.translationAPIKey = translationAPIKey
    }

    public static let defaultValue = AppSettings(
        hotkey: .defaultValue,
        sourceLanguage: .auto,
        targetLanguage: Locale.Language(identifier: "zh-Hans"),
        translationProvider: .siliconFlow,
        translationAPIKey: ""
    )

    public func withTargetLanguage(_ identifier: String) -> AppSettings {
        var copy = self
        copy.targetLanguage = Locale.Language(identifier: identifier)
        return copy
    }
}
