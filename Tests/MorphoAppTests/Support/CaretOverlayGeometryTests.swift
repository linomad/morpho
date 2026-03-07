import AppKit
import XCTest
@testable import MorphoApp

final class CaretOverlayGeometryTests: XCTestCase {
    func testPanelOriginPlacesOverlayToRightOfCaretAndCentersVertically() {
        let caretRect = CGRect(x: 100, y: 240, width: 0, height: 20)
        let origin = CaretLoadingOverlay.panelOrigin(
            for: caretRect,
            overlaySize: CGSize(width: 20, height: 20),
            withinVisibleFrame: CGRect(x: 0, y: 0, width: 500, height: 400)
        )

        XCTAssertEqual(origin, CGPoint(x: 104, y: 240))
    }

    func testPanelOriginClampsToRightEdgeOfVisibleFrame() {
        let caretRect = CGRect(x: 392, y: 120, width: 6, height: 20)
        let origin = CaretLoadingOverlay.panelOrigin(
            for: caretRect,
            overlaySize: CGSize(width: 20, height: 20),
            withinVisibleFrame: CGRect(x: 0, y: 0, width: 400, height: 300)
        )

        XCTAssertEqual(origin, CGPoint(x: 380, y: 120))
    }

    func testPanelOriginClampsToBottomEdgeOfVisibleFrame() {
        let caretRect = CGRect(x: 100, y: 2, width: 0, height: 8)
        let origin = CaretLoadingOverlay.panelOrigin(
            for: caretRect,
            overlaySize: CGSize(width: 20, height: 20),
            withinVisibleFrame: CGRect(x: 0, y: 0, width: 500, height: 400)
        )

        XCTAssertEqual(origin, CGPoint(x: 104, y: 0))
    }

    func testPanelOriginClampsToTopEdgeOfVisibleFrame() {
        let caretRect = CGRect(x: 100, y: 394, width: 0, height: 20)
        let origin = CaretLoadingOverlay.panelOrigin(
            for: caretRect,
            overlaySize: CGSize(width: 20, height: 20),
            withinVisibleFrame: CGRect(x: 0, y: 0, width: 500, height: 400)
        )

        XCTAssertEqual(origin, CGPoint(x: 104, y: 380))
    }
}
