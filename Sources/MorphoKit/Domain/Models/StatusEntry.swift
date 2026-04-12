import Foundation

public enum StatusSeverity: Equatable, Sendable {
    case info
    case success
    case warning
    case error
}

public enum StatusCode: String, Equatable, Sendable, Codable {
    case ready
    case translationCompleted
    case polishCompleted
    case workflowBlocked
    case workflowFailed
    case hotkeyInitFailed
    case hotkeyRegisterFailed
    case launchAtLoginUnsupportedSystem
}

public struct StatusEntry: Equatable, Sendable {
    public let code: StatusCode
    public let messageKey: String
    public let messageArguments: [String]
    public let severity: StatusSeverity
    public let createdAt: Date

    public init(
        code: StatusCode,
        messageKey: String,
        messageArguments: [String] = [],
        severity: StatusSeverity,
        createdAt: Date = Date()
    ) {
        self.code = code
        self.messageKey = messageKey
        self.messageArguments = messageArguments
        self.severity = severity
        self.createdAt = createdAt
    }
}

public enum TranslationExecutionResult: Equatable, Sendable {
    case success
    case failure(TranslationWorkflowError)
}
