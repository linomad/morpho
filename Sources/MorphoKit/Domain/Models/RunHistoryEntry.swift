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
    public let workMode: WorkMode

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        inputText: String,
        outputText: String,
        sourceLanguageIdentifier: String,
        targetLanguageIdentifier: String,
        translationProvider: TranslationProvider,
        translationModelID: String,
        workMode: WorkMode = .translate
    ) {
        self.id = id
        self.createdAt = createdAt
        self.inputText = inputText
        self.outputText = outputText
        self.sourceLanguageIdentifier = sourceLanguageIdentifier
        self.targetLanguageIdentifier = targetLanguageIdentifier
        self.translationProvider = translationProvider
        self.translationModelID = translationModelID
        self.workMode = workMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        inputText = try container.decode(String.self, forKey: .inputText)
        outputText = try container.decode(String.self, forKey: .outputText)
        sourceLanguageIdentifier = try container.decode(String.self, forKey: .sourceLanguageIdentifier)
        targetLanguageIdentifier = try container.decode(String.self, forKey: .targetLanguageIdentifier)
        translationProvider = try container.decode(TranslationProvider.self, forKey: .translationProvider)
        translationModelID = try container.decode(String.self, forKey: .translationModelID)
        workMode = try container.decodeIfPresent(WorkMode.self, forKey: .workMode) ?? .translate
    }
}
