import Foundation

public enum InputLengthValidationResult: Equatable, Sendable {
    case withinLimit
    case tooLong(actual: Int, limit: Int)
}

public struct InputTextLengthPolicy: Sendable {
    public let maxCharacters: Int

    public init(maxCharacters: Int = 5_000) {
        self.maxCharacters = max(1, maxCharacters)
    }

    public func validate(_ text: String) -> InputLengthValidationResult {
        let count = text.count
        return count <= maxCharacters
            ? .withinLimit
            : .tooLong(actual: count, limit: maxCharacters)
    }
}
