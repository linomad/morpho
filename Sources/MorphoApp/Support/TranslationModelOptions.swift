import Foundation
import MorphoKit

struct TranslationModelOption: Identifiable, Equatable {
    let id: String
    let title: String
}

enum TranslationModelOptions {
    static let all: [TranslationModelOption] = [
        TranslationModelOption(
            id: AppSettings.defaultTranslationModelID,
            title: "DeepSeek V3"
        )
    ]

    static func normalizedID(_ identifier: String) -> String {
        if all.contains(where: { $0.id == identifier }) {
            return identifier
        }
        return AppSettings.defaultTranslationModelID
    }

    static func title(for identifier: String) -> String {
        let normalized = normalizedID(identifier)
        return all.first(where: { $0.id == normalized })?.title ?? normalized
    }
}
