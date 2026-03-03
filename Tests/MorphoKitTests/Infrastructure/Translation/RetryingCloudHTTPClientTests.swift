import Foundation
import XCTest
@testable import MorphoKit

final class RetryingCloudHTTPClientTests: XCTestCase {
    func testSendRetriesForRateLimitAndServerErrorThenSucceeds() async throws {
        let base = SequencedHTTPClientStub(
            responses: [
                .init(statusCode: 429),
                .init(statusCode: 500),
                .init(statusCode: 200),
            ]
        )
        let recorder = SleepRecorder()
        let client = RetryingCloudHTTPClient(
            wrapped: base,
            policy: CloudRetryPolicy(maxAttempts: 3, baseDelay: 0.2, maxDelay: 2),
            sleep: recorder.record
        )

        let request = URLRequest(url: URL(string: "https://example.com")!)
        let (_, response) = try await client.send(request)

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(base.sendCount, 3)
        let recordedDelays = await recorder.snapshot()
        XCTAssertEqual(recordedDelays, [0.2, 0.4])
    }

    func testSendStopsAtMaxAttemptsAndReturnsLastResponse() async throws {
        let base = SequencedHTTPClientStub(
            responses: [
                .init(statusCode: 503),
                .init(statusCode: 503),
                .init(statusCode: 503),
            ]
        )
        let recorder = SleepRecorder()
        let client = RetryingCloudHTTPClient(
            wrapped: base,
            policy: CloudRetryPolicy(maxAttempts: 3, baseDelay: 0.1, maxDelay: 2),
            sleep: recorder.record
        )

        let request = URLRequest(url: URL(string: "https://example.com")!)
        let (_, response) = try await client.send(request)

        XCTAssertEqual(response.statusCode, 503)
        XCTAssertEqual(base.sendCount, 3)
        let recordedDelays = await recorder.snapshot()
        XCTAssertEqual(recordedDelays, [0.1, 0.2])
    }

    func testSendUsesRetryAfterHeaderWhenPresent() async throws {
        let base = SequencedHTTPClientStub(
            responses: [
                .init(statusCode: 429, headers: ["Retry-After": "3"]),
                .init(statusCode: 200),
            ]
        )
        let recorder = SleepRecorder()
        let client = RetryingCloudHTTPClient(
            wrapped: base,
            policy: CloudRetryPolicy(maxAttempts: 3, baseDelay: 0.1, maxDelay: 5),
            sleep: recorder.record
        )

        let request = URLRequest(url: URL(string: "https://example.com")!)
        let (_, response) = try await client.send(request)

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(base.sendCount, 2)
        let recordedDelays = await recorder.snapshot()
        XCTAssertEqual(recordedDelays, [3])
    }
}

private actor SleepRecorder {
    private var values: [TimeInterval] = []

    func record(_ seconds: TimeInterval) async throws {
        values.append(seconds)
    }

    func snapshot() -> [TimeInterval] {
        values
    }
}

private final class SequencedHTTPClientStub: CloudHTTPClient {
    struct Response {
        let statusCode: Int
        let headers: [String: String]
        let data: Data

        init(statusCode: Int, headers: [String: String] = [:], data: Data = Data()) {
            self.statusCode = statusCode
            self.headers = headers
            self.data = data
        }
    }

    private var responses: [Response]
    private(set) var sendCount: Int = 0

    init(responses: [Response]) {
        self.responses = responses
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        sendCount += 1
        guard !responses.isEmpty else {
            XCTFail("No more responses configured.")
            throw TranslationWorkflowError.translationFailed
        }

        let next = responses.removeFirst()
        let url = request.url ?? URL(string: "https://example.com")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: next.statusCode,
            httpVersion: nil,
            headerFields: next.headers
        )!
        return (next.data, response)
    }
}
