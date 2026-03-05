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

public struct AutoSwitchLanguagePair: Equatable, Sendable {
    public var firstLanguage: Locale.Language
    public var secondLanguage: Locale.Language

    public init(firstLanguage: Locale.Language, secondLanguage: Locale.Language) {
        self.firstLanguage = firstLanguage
        self.secondLanguage = secondLanguage
    }
}

public struct AppSettings: Equatable, Sendable {
    public static let defaultInterfaceLanguageCode = "system"
    public static let defaultTranslationModelID = "deepseek-ai/DeepSeek-V3"
    public static let defaultAutoSwitchFirstLanguage = Locale.Language(identifier: "en")

    public var hotkey: HotkeyShortcut
    public var isHotkeyEnabled: Bool
    public var sourceLanguage: LanguageSource
    public var targetLanguage: Locale.Language
    public var autoSwitchLanguagePair: AutoSwitchLanguagePair?
    public var translationProvider: TranslationProvider
    public var translationAPIKey: String
    public var launchAtLoginPreferred: Bool
    public var interfaceLanguageCode: String
    public var translationModelID: String

    public init(
        hotkey: HotkeyShortcut,
        isHotkeyEnabled: Bool = true,
        sourceLanguage: LanguageSource,
        targetLanguage: Locale.Language,
        autoSwitchLanguagePair: AutoSwitchLanguagePair? = nil,
        translationProvider: TranslationProvider,
        translationAPIKey: String,
        launchAtLoginPreferred: Bool = false,
        interfaceLanguageCode: String = AppSettings.defaultInterfaceLanguageCode,
        translationModelID: String = AppSettings.defaultTranslationModelID
    ) {
        self.hotkey = hotkey
        self.isHotkeyEnabled = isHotkeyEnabled
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.autoSwitchLanguagePair = autoSwitchLanguagePair
        self.translationProvider = translationProvider
        self.translationAPIKey = translationAPIKey
        self.launchAtLoginPreferred = launchAtLoginPreferred
        self.interfaceLanguageCode = interfaceLanguageCode
        self.translationModelID = translationModelID
    }

    public static let defaultValue = AppSettings(
        hotkey: .defaultValue,
        isHotkeyEnabled: true,
        sourceLanguage: .auto,
        targetLanguage: Locale.Language(identifier: "zh-Hans"),
        autoSwitchLanguagePair: AppSettings.makeDefaultAutoSwitchLanguagePair(
            targetLanguage: Locale.Language(identifier: "zh-Hans")
        ),
        translationProvider: .siliconFlow,
        translationAPIKey: "",
        launchAtLoginPreferred: false,
        interfaceLanguageCode: AppSettings.defaultInterfaceLanguageCode,
        translationModelID: AppSettings.defaultTranslationModelID
    )

    public func withTargetLanguage(_ identifier: String) -> AppSettings {
        var copy = self
        copy.targetLanguage = Locale.Language(identifier: identifier)
        return copy
    }

    public static func makeDefaultAutoSwitchLanguagePair(
        targetLanguage: Locale.Language
    ) -> AutoSwitchLanguagePair {
        AutoSwitchLanguagePair(
            firstLanguage: defaultAutoSwitchFirstLanguage,
            secondLanguage: targetLanguage
        )
    }
}
