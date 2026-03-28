import AppKit
import XCTest
@testable import MorphoApp

final class CaretRectValidationTests: XCTestCase {
    private let primaryScreenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let secondaryScreenFrame = CGRect(x: 1440, y: 0, width: 1280, height: 900)

    func testAppKitRectConvertsFromTopLeftAXCoordinates() {
        let axRect = CGRect(x: 100, y: 200, width: 12, height: 20)

        let rect = CaretRectLocator.appKitRect(
            fromAXRect: axRect,
            primaryScreenFrame: primaryScreenFrame
        )

        XCTAssertEqual(rect, CGRect(x: 100, y: 680, width: 12, height: 20))
    }

    func testValidateAXRectAcceptsReasonableRectOnSecondaryScreen() {
        let axRect = CGRect(x: 1500, y: 120, width: 10, height: 18)

        let isValid = CaretRectLocator.validateAXRect(
            axRect,
            screenFrames: [primaryScreenFrame, secondaryScreenFrame],
            primaryScreenFrame: primaryScreenFrame
        )

        XCTAssertTrue(isValid)
    }

    func testValidateAXRectRejectsZeroRect() {
        let isValid = CaretRectLocator.validateAXRect(
            .zero,
            screenFrames: [primaryScreenFrame],
            primaryScreenFrame: primaryScreenFrame
        )

        XCTAssertFalse(isValid)
    }

    func testValidateAXRectRejectsOffscreenRect() {
        let axRect = CGRect(x: 4000, y: 120, width: 10, height: 18)

        let isValid = CaretRectLocator.validateAXRect(
            axRect,
            screenFrames: [primaryScreenFrame, secondaryScreenFrame],
            primaryScreenFrame: primaryScreenFrame
        )

        XCTAssertFalse(isValid)
    }

    func testValidateAXRectRejectsRectWithUnreasonableHeight() {
        let axRect = CGRect(x: 100, y: 120, width: 10, height: 7)

        let isValid = CaretRectLocator.validateAXRect(
            axRect,
            screenFrames: [primaryScreenFrame],
            primaryScreenFrame: primaryScreenFrame
        )

        XCTAssertFalse(isValid)
    }

    func testInsertionPointRectUsesPreviousCharacterRightEdge() {
        let characterRect = CGRect(x: 40, y: 80, width: 8, height: 18)

        let caretRect = CaretRectLocator.insertionPointRect(fromCharacterRect: characterRect)

        XCTAssertEqual(caretRect, CGRect(x: 48, y: 80, width: 0, height: 18))
    }
}
