import Foundation

public enum StatusSeverity: Equatable, Sendable {
    case info
    case success
    case warning
    case error
}

public struct StatusEntry: Equatable, Sendable {
    public let message: String
    public let severity: StatusSeverity
    public let createdAt: Date

    public init(message: String, severity: StatusSeverity, createdAt: Date = Date()) {
        self.message = message
        self.severity = severity
        self.createdAt = createdAt
    }
}

public enum TranslationExecutionResult: Equatable, Sendable {
    case success
    case failure(TranslationWorkflowError)
}
