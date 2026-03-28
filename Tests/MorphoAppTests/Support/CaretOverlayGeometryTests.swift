import AppKit
import XCTest
@testable import MorphoApp

final class CaretOverlayGeometryTests: XCTestCase {
    func testOverlayUsesCompactDefaultSize() {
        XCTAssertEqual(CaretLoadingOverlay.overlaySize, CGSize(width: 14, height: 14))
    }

    func testOverlayUsesCompactStrokeWidth() {
        XCTAssertEqual(CaretLoadingOverlay.spinnerLineWidth, 1.5)
    }

    func testOverlayUsesSlightlyLargerHorizontalSpacing() {
        XCTAssertEqual(CaretLoadingOverlay.horizontalSpacing, 6)
    }

    func testSpinnerArcRectCentersStrokeWithinCanvas() {
        let rect = CaretLoadingOverlay.spinnerArcRect(
            canvasSize: CGSize(width: 14, height: 14),
            lineWidth: 1.5
        )

        XCTAssertEqual(rect, CGRect(x: 0.75, y: 0.75, width: 12.5, height: 12.5))
    }

    func testSpinnerUsesPartialArcForLoadingVisual() {
        XCTAssertEqual(CaretLoadingOverlay.spinnerStartAngle, -CGFloat.pi / 2)
        XCTAssertEqual(CaretLoadingOverlay.spinnerSweepAngle, CGFloat.pi * 1.65)
    }

    func testSpinnerUsesSubtleOpacityMultiplier() {
        XCTAssertEqual(CaretLoadingOverlay.spinnerOpacityMultiplier, 0.2)
    }

    func testSpinnerColorResolvesDifferentlyForLightAndDarkAppearance() {
        let aqua = NSAppearance(named: .aqua)!
        let darkAqua = NSAppearance(named: .darkAqua)!

        let lightColor = CaretLoadingOverlay.resolvedSpinnerColor(for: aqua)
        let darkColor = CaretLoadingOverlay.resolvedSpinnerColor(for: darkAqua)

        XCTAssertNotEqual(
            lightColor.usingColorSpace(NSColorSpace.deviceRGB),
            darkColor.usingColorSpace(NSColorSpace.deviceRGB)
        )
    }

    func testSpinnerColorIsSlightlyWeakerThanSecondaryLabelColor() {
        let aqua = NSAppearance(named: .aqua)!
        let darkAqua = NSAppearance(named: .darkAqua)!

        let baseLight = resolvedColor(.secondaryLabelColor, appearance: aqua)
        let baseDark = resolvedColor(.secondaryLabelColor, appearance: darkAqua)
        let lightColor = CaretLoadingOverlay.resolvedSpinnerColor(for: aqua)
        let darkColor = CaretLoadingOverlay.resolvedSpinnerColor(for: darkAqua)

        XCTAssertEqual(lightColor.alphaComponent, baseLight.alphaComponent * 0.2, accuracy: 0.001)
        XCTAssertEqual(darkColor.alphaComponent, baseDark.alphaComponent * 0.2, accuracy: 0.001)
    }

    func testPanelOriginPlacesOverlayToRightOfCaretAndCentersVertically() {
        let caretRect = CGRect(x: 100, y: 240, width: 0, height: 20)
        let origin = CaretLoadingOverlay.panelOrigin(
            for: caretRect,
            overlaySize: CaretLoadingOverlay.overlaySize,
            withinVisibleFrame: CGRect(x: 0, y: 0, width: 500, height: 400)
        )

        XCTAssertEqual(origin, CGPoint(x: 106, y: 243))
    }

    func testPanelOriginClampsToRightEdgeOfVisibleFrame() {
        let caretRect = CGRect(x: 392, y: 120, width: 6, height: 20)
        let origin = CaretLoadingOverlay.panelOrigin(
            for: caretRect,
            overlaySize: CaretLoadingOverlay.overlaySize,
            withinVisibleFrame: CGRect(x: 0, y: 0, width: 400, height: 300)
        )

        XCTAssertEqual(origin, CGPoint(x: 386, y: 123))
    }

    func testPanelOriginClampsToBottomEdgeOfVisibleFrame() {
        let caretRect = CGRect(x: 100, y: 2, width: 0, height: 8)
        let origin = CaretLoadingOverlay.panelOrigin(
            for: caretRect,
            overlaySize: CaretLoadingOverlay.overlaySize,
            withinVisibleFrame: CGRect(x: 0, y: 0, width: 500, height: 400)
        )

        XCTAssertEqual(origin, CGPoint(x: 106, y: 0))
    }

    func testPanelOriginClampsToTopEdgeOfVisibleFrame() {
        let caretRect = CGRect(x: 100, y: 394, width: 0, height: 20)
        let origin = CaretLoadingOverlay.panelOrigin(
            for: caretRect,
            overlaySize: CaretLoadingOverlay.overlaySize,
            withinVisibleFrame: CGRect(x: 0, y: 0, width: 500, height: 400)
        )

        XCTAssertEqual(origin, CGPoint(x: 106, y: 386))
    }

    private func resolvedColor(_ color: NSColor, appearance: NSAppearance) -> NSColor {
        var resolvedColor: NSColor?
        appearance.performAsCurrentDrawingAppearance {
            resolvedColor = color.usingColorSpace(NSColorSpace.deviceRGB)
        }
        return resolvedColor ?? color
    }
}
