import Foundation
import XCTest
@testable import MorphoKit

@MainActor
final class TranslationTaskCoordinatorTests: XCTestCase {
    func testSubmitFailsWhenBridgeIsNotReadyInTime() async {
        let coordinator = TranslationTaskCoordinator(
            bridgeReadyTimeoutNanoseconds: 50_000_000,
            requestStartTimeoutNanoseconds: 500_000_000
        )

        let error = await captureSubmitError(from: coordinator)
        XCTAssertEqual(error, .translationSessionStartupTimeout)
    }

    func testSubmitDoesNotLeaveCoordinatorInProgressAfterTimeout() async {
        let coordinator = TranslationTaskCoordinator(
            bridgeReadyTimeoutNanoseconds: 50_000_000,
            requestStartTimeoutNanoseconds: 80_000_000
        )
        coordinator.markBridgeReady()

        let firstError = await captureSubmitError(from: coordinator)
        XCTAssertEqual(firstError, .translationSessionStartupTimeout)

        let secondError = await captureSubmitError(from: coordinator)
        XCTAssertEqual(secondError, .translationSessionStartupTimeout)
    }

    private func captureSubmitError(
        from coordinator: TranslationTaskCoordinator,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async -> TranslationWorkflowError? {
        let completed = expectation(description: "submit completes")
        var capturedError: TranslationWorkflowError?

        Task { @MainActor in
            do {
                _ = try await coordinator.submit(
                    text: "hello",
                    source: nil,
                    target: Locale.Language(identifier: "zh-Hans")
                )
                XCTFail("submit should not succeed in this test scenario.", file: file, line: line)
            } catch let error as TranslationWorkflowError {
                capturedError = error
            } catch {
                XCTFail("Unexpected error: \(error)", file: file, line: line)
            }
            completed.fulfill()
        }

        await fulfillment(of: [completed], timeout: 1.0)
        return capturedError
    }
}
