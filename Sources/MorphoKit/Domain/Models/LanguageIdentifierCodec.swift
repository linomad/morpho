import Foundation

public enum LanguageIdentifierCodec {
    public static func persistedIdentifier(for language: Locale.Language) -> String {
        language.maximalIdentifier
    }

    public static func displayIdentifier(
        for language: Locale.Language,
        supportedIdentifiers: [String]
    ) -> String {
        let minimalIdentifier = language.minimalIdentifier
        if supportedIdentifiers.contains(minimalIdentifier) {
            return minimalIdentifier
        }

        if let matchedIdentifier = supportedIdentifiers.first(where: {
            Locale.Language(identifier: $0).minimalIdentifier == minimalIdentifier
        }) {
            return matchedIdentifier
        }

        return minimalIdentifier
    }
}
