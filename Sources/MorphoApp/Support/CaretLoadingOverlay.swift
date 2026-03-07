import AppKit
import Foundation

@MainActor
final class CaretLoadingOverlay {
    static let overlaySize = CGSize(width: 20, height: 20)
    nonisolated private static let horizontalSpacing: CGFloat = 4

    private let panel: NSPanel
    private let spinner: NSProgressIndicator

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

        spinner = NSProgressIndicator(frame: NSRect(origin: .zero, size: Self.overlaySize))
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isIndeterminate = true
        spinner.isDisplayedWhenStopped = false

        let contentView = NSView(frame: NSRect(origin: .zero, size: Self.overlaySize))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.clear.cgColor
        spinner.autoresizingMask = [.width, .height]
        contentView.addSubview(spinner)
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
        spinner.startAnimation(nil)
        panel.orderFrontRegardless()
    }

    func hide() {
        spinner.stopAnimation(nil)
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
}
