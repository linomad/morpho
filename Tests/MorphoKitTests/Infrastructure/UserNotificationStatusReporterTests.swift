import XCTest
@testable import MorphoKit

final class UserNotificationStatusReporterTests: XCTestCase {
    func testResolvedMessageUsesMessageKeyByDefault() {
        let reporter = UserNotificationStatusReporter()
        let entry = StatusEntry(
            code: .workflowBlocked,
            messageKey: "error.input_text_too_long",
            messageArguments: ["5001", "5000"],
            severity: .warning
        )

        XCTAssertEqual(reporter.resolvedMessage(for: entry), "error.input_text_too_long")
    }

    func testResolvedMessageUsesInjectedResolver() {
        let reporter = UserNotificationStatusReporter { entry in
            "localized:\(entry.messageArguments.joined(separator: "/"))"
        }
        let entry = StatusEntry(
            code: .workflowBlocked,
            messageKey: "error.input_text_too_long",
            messageArguments: ["5001", "5000"],
            severity: .warning
        )

        XCTAssertEqual(reporter.resolvedMessage(for: entry), "localized:5001/5000")
    }
}
