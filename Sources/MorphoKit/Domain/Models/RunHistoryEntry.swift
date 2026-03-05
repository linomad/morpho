import Foundation

public struct RunHistoryEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let inputText: String
    public let outputText: String
    public let sourceLanguageIdentifier: String
    public let targetLanguageIdentifier: String
    public let translationProvider: TranslationProvider
    public let translationModelID: String

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        inputText: String,
        outputText: String,
        sourceLanguageIdentifier: String,
        targetLanguageIdentifier: String,
        translationProvider: TranslationProvider,
        translationModelID: String
    ) {
        self.id = id
        self.createdAt = createdAt
        self.inputText = inputText
        self.outputText = outputText
        self.sourceLanguageIdentifier = sourceLanguageIdentifier
        self.targetLanguageIdentifier = targetLanguageIdentifier
        self.translationProvider = translationProvider
        self.translationModelID = translationModelID
    }
}
