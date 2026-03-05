import Foundation

public struct TextContext: Equatable, Sendable {
    public let appBundleId: String
    public let fullText: String
    public let selectedRange: NSRange?
    public let selectedText: String?
    public let isSecureField: Bool
    public let replacementToken: UUID?

    public init(
        appBundleId: String,
        fullText: String,
        selectedRange: NSRange?,
        selectedText: String?,
        isSecureField: Bool,
        replacementToken: UUID? = nil
    ) {
        self.appBundleId = appBundleId
        self.fullText = fullText
        self.selectedRange = selectedRange
        self.selectedText = selectedText
        self.isSecureField = isSecureField
        self.replacementToken = replacementToken
    }
}

public enum ReplacementMode: Equatable, Sendable {
    case selection
    case entireField
}

public enum LanguageSource: Equatable, Sendable {
    case auto
    case fixed(Locale.Language)
}

public enum TranslationProvider: String, CaseIterable, Codable, Equatable, Sendable {
    case siliconFlow
}
