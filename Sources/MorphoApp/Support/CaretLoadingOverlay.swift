import AppKit
import Foundation
import QuartzCore

@MainActor
final class CaretLoadingOverlay {
    nonisolated static let overlaySize = CGSize(width: 14, height: 14)
    nonisolated static let spinnerLineWidth: CGFloat = 1.5
    nonisolated static let spinnerStartAngle: CGFloat = -.pi / 2
    nonisolated static let spinnerSweepAngle: CGFloat = .pi * 1.65
    nonisolated static let spinnerOpacityMultiplier: CGFloat = 0.2
    nonisolated static let horizontalSpacing: CGFloat = 6
    nonisolated private static let animationKey = "morpho.caretLoadingOverlay.rotation"
    nonisolated private static let rotationDuration: CFTimeInterval = 0.75

    private let panel: NSPanel
    private let spinnerLayer: CAShapeLayer

    init() {
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.overlaySize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        spinnerLayer = CAShapeLayer()
        spinnerLayer.frame = CGRect(origin: .zero, size: Self.overlaySize)
        spinnerLayer.path = Self.spinnerPath(
            canvasSize: Self.overlaySize,
            lineWidth: Self.spinnerLineWidth
        )
        spinnerLayer.fillColor = NSColor.clear.cgColor
        spinnerLayer.strokeColor = NSColor.secondaryLabelColor.cgColor
        spinnerLayer.lineWidth = Self.spinnerLineWidth
        spinnerLayer.lineCap = .round

        let contentView = NSView(frame: NSRect(origin: .zero, size: Self.overlaySize))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
        contentView.layer?.addSublayer(spinnerLayer)
        panel.contentView = contentView
    }

    func show() {
        guard
            let caretRect = CaretRectLocator.queryCaretRect(),
            let visibleFrame = Self.visibleFrame(for: caretRect)
        else {
            return
        }

        let origin = Self.panelOrigin(
            for: caretRect,
            overlaySize: Self.overlaySize,
            withinVisibleFrame: visibleFrame
        )

        panel.setFrame(NSRect(origin: origin, size: Self.overlaySize), display: false)
        syncAppearance()
        startAnimating()
        panel.orderFrontRegardless()
    }

    func hide() {
        stopAnimating()
        panel.orderOut(nil)
    }

    nonisolated static func panelOrigin(
        for caretRect: CGRect,
        overlaySize: CGSize,
        withinVisibleFrame visibleFrame: CGRect
    ) -> CGPoint {
        let unclampedOrigin = CGPoint(
            x: caretRect.maxX + horizontalSpacing,
            y: caretRect.midY - (overlaySize.height / 2)
        )

        let maxX = max(visibleFrame.minX, visibleFrame.maxX - overlaySize.width)
        let maxY = max(visibleFrame.minY, visibleFrame.maxY - overlaySize.height)

        return CGPoint(
            x: min(max(unclampedOrigin.x, visibleFrame.minX), maxX),
            y: min(max(unclampedOrigin.y, visibleFrame.minY), maxY)
        )
    }

    private static func visibleFrame(for caretRect: CGRect) -> CGRect? {
        if let screen = NSScreen.screens.first(where: { $0.frame.intersects(caretRect) }) {
            return screen.visibleFrame
        }

        return NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame
    }

    nonisolated static func resolvedSpinnerColor(for appearance: NSAppearance) -> NSColor {
        var resolvedColor: NSColor?
        appearance.performAsCurrentDrawingAppearance {
            resolvedColor = NSColor.secondaryLabelColor.usingColorSpace(.deviceRGB)
        }
        let baseColor = resolvedColor ?? NSColor.secondaryLabelColor
        return baseColor.withAlphaComponent(baseColor.alphaComponent * spinnerOpacityMultiplier)
    }

    nonisolated static func spinnerArcRect(canvasSize: CGSize, lineWidth: CGFloat) -> CGRect {
        CGRect(
            x: lineWidth / 2,
            y: lineWidth / 2,
            width: canvasSize.width - lineWidth,
            height: canvasSize.height - lineWidth
        )
    }

    private func startAnimating() {
        guard spinnerLayer.animation(forKey: Self.animationKey) == nil else {
            return
        }

        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = CGFloat.pi * 2
        rotation.duration = Self.rotationDuration
        rotation.repeatCount = .infinity
        rotation.timingFunction = CAMediaTimingFunction(name: .linear)
        spinnerLayer.add(rotation, forKey: Self.animationKey)
    }

    private func stopAnimating() {
        spinnerLayer.removeAnimation(forKey: Self.animationKey)
    }

    private func syncAppearance() {
        let appearance = NSApp.effectiveAppearance
        panel.appearance = appearance
        spinnerLayer.strokeColor = Self.resolvedSpinnerColor(for: appearance).cgColor
    }

    private static func spinnerPath(canvasSize: CGSize, lineWidth: CGFloat) -> CGPath {
        let rect = spinnerArcRect(canvasSize: canvasSize, lineWidth: lineWidth)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let path = CGMutablePath()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: spinnerStartAngle,
            endAngle: spinnerStartAngle + spinnerSweepAngle,
            clockwise: false
        )
        return path
    }
}
