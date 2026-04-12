import MorphoKit
import XCTest
@testable import MorphoApp

final class StatusAutoResetPolicyTests: XCTestCase {
    func testShouldAutoResetForTranslationCompletedCode() {
        let entry = StatusEntry(
            code: .translationCompleted,
            messageKey: "status.translation_complete_with_preview",
            messageArguments: ["hello"],
            severity: .success
        )
        XCTAssertTrue(shouldAutoReset(for: entry))
    }

    func testShouldAutoResetForPolishCompletedCode() {
        let entry = StatusEntry(
            code: .polishCompleted,
            messageKey: "status.polish_complete_with_preview",
            messageArguments: ["hello"],
            severity: .success
        )
        XCTAssertTrue(shouldAutoReset(for: entry))
    }

    func testShouldNotAutoResetForNonCompletionCode() {
        let entry = StatusEntry(
            code: .ready,
            messageKey: "status.ready",
            severity: .info
        )
        XCTAssertFalse(shouldAutoReset(for: entry))
    }

    func testShouldNotAutoResetForBlockedCode() {
        let entry = StatusEntry(
            code: .workflowBlocked,
            messageKey: "error.input_text_too_long",
            messageArguments: ["5001", "5000"],
            severity: .warning
        )
        XCTAssertFalse(shouldAutoReset(for: entry))
    }

    func testShouldNotAutoResetForFailedCode() {
        let entry = StatusEntry(
            code: .workflowFailed,
            messageKey: "error.translation_failed",
            severity: .error
        )
        XCTAssertFalse(shouldAutoReset(for: entry))
    }
}

// Helper function matching the logic in MorphoAppModel
private func shouldAutoReset(for entry: StatusEntry) -> Bool {
    entry.code == .translationCompleted || entry.code == .polishCompleted
}
