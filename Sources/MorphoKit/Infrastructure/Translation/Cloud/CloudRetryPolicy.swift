import Foundation

public struct CloudRetryPolicy: Equatable, Sendable {
    public let maxAttempts: Int
    public let baseDelay: TimeInterval
    public let maxDelay: TimeInterval

    public init(
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 0.35,
        maxDelay: TimeInterval = 3
    ) {
        self.maxAttempts = max(maxAttempts, 1)
        self.baseDelay = max(baseDelay, 0)
        self.maxDelay = max(maxDelay, 0)
    }

    public static let defaultValue = CloudRetryPolicy()

    func shouldRetry(statusCode: Int, attempt: Int) -> Bool {
        guard attempt < maxAttempts else {
            return false
        }

        if statusCode == 429 {
            return true
        }

        return (500 ... 599).contains(statusCode)
    }

    func delaySeconds(forAttempt attempt: Int, response: HTTPURLResponse) -> TimeInterval {
        if let retryAfter = parseRetryAfter(response: response) {
            return min(maxDelay, retryAfter)
        }

        let exponent = max(attempt - 1, 0)
        let exponentialDelay = baseDelay * pow(2, Double(exponent))
        return min(maxDelay, exponentialDelay)
    }

    private func parseRetryAfter(response: HTTPURLResponse) -> TimeInterval? {
        guard
            let value = response.value(forHTTPHeaderField: "Retry-After"),
            let seconds = TimeInterval(value),
            seconds > 0
        else {
            return nil
        }

        return seconds
    }
}
