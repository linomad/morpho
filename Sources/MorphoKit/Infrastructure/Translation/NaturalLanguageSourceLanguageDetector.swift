import Foundation
import NaturalLanguage

public final class NaturalLanguageSourceLanguageDetector: SourceLanguageDetecting {
    private let minimumConfidence: Double

    public init(minimumConfidence: Double = 0.2) {
        self.minimumConfidence = minimumConfidence
    }

    public func detectLanguage(for text: String) -> Locale.Language? {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return nil
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(normalized)

        guard let dominantLanguage = recognizer.dominantLanguage else {
            return nil
        }

        let confidence = recognizer.languageHypotheses(withMaximum: 1)[dominantLanguage] ?? 0
        guard confidence >= minimumConfidence else {
            return nil
        }

        return Locale.Language(identifier: dominantLanguage.rawValue)
    }
}
