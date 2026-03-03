import Foundation

public final class RetryingCloudHTTPClient: CloudHTTPClient {
    public typealias SleepFunction = @Sendable (TimeInterval) async throws -> Void

    private let wrapped: any CloudHTTPClient
    private let policy: CloudRetryPolicy
    private let sleep: SleepFunction

    public init(
        wrapped: any CloudHTTPClient,
        policy: CloudRetryPolicy = .defaultValue,
        sleep: @escaping SleepFunction = RetryingCloudHTTPClient.defaultSleep
    ) {
        self.wrapped = wrapped
        self.policy = policy
        self.sleep = sleep
    }

    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var attempt = 1

        while true {
            let result = try await wrapped.send(request)
            let response = result.1
            guard policy.shouldRetry(statusCode: response.statusCode, attempt: attempt) else {
                return result
            }

            let delay = policy.delaySeconds(forAttempt: attempt, response: response)
            attempt += 1
            try await sleep(delay)
        }
    }

    public static func defaultSleep(_ seconds: TimeInterval) async throws {
        guard seconds > 0 else {
            return
        }

        let nanoseconds = UInt64((seconds * 1_000_000_000).rounded())
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}
