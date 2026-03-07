import AppKit
import ApplicationServices
import Foundation

enum CaretRectLocator {
    private static let minimumRectHeight: CGFloat = 8
    private static let maximumRectHeight: CGFloat = 120

    static func queryCaretRect() -> CGRect? {
        let screenFrames = NSScreen.screens.map(\.frame)
        guard
            let primaryScreenFrame = NSScreen.screens.first?.frame,
            !screenFrames.isEmpty,
            let focusedElement = focusedElement()
        else {
            return nil
        }

        if let rect = queryViaStandardAX(
            focusedElement,
            screenFrames: screenFrames,
            primaryScreenFrame: primaryScreenFrame
        ) {
            return rect
        }

        return queryViaTextMarker(
            focusedElement,
            screenFrames: screenFrames,
            primaryScreenFrame: primaryScreenFrame
        )
    }

    static func appKitRect(fromAXRect axRect: CGRect, primaryScreenFrame: CGRect) -> CGRect {
        CGRect(
            x: axRect.origin.x,
            y: primaryScreenFrame.maxY - axRect.origin.y - axRect.height,
            width: axRect.width,
            height: axRect.height
        )
    }

    static func validateAXRect(
        _ rect: CGRect,
        screenFrames: [CGRect],
        primaryScreenFrame: CGRect
    ) -> Bool {
        guard
            !screenFrames.isEmpty,
            rect.origin.x.isFinite,
            rect.origin.y.isFinite,
            rect.width.isFinite,
            rect.height.isFinite,
            !rect.isNull,
            !rect.isInfinite,
            !rect.isEmpty,
            rect != .zero
        else {
            return false
        }

        let appKitRect = appKitRect(fromAXRect: rect, primaryScreenFrame: primaryScreenFrame)
        guard screenFrames.contains(where: { $0.intersects(appKitRect) }) else {
            return false
        }

        let maxWidth = screenFrames.map(\.width).max() ?? primaryScreenFrame.width
        guard
            rect.height >= minimumRectHeight,
            rect.height <= maximumRectHeight,
            rect.width <= maxWidth
        else {
            return false
        }

        return true
    }

    static func insertionPointRect(fromCharacterRect rect: CGRect) -> CGRect {
        CGRect(x: rect.maxX, y: rect.minY, width: 0, height: rect.height)
    }

    private static func queryViaStandardAX(
        _ element: AXUIElement,
        screenFrames: [CGRect],
        primaryScreenFrame: CGRect
    ) -> CGRect? {
        guard let selectedRangeValue = selectedRangeValue(from: element) else {
            return nil
        }

        if let rect = boundsForRange(element: element, rangeValue: selectedRangeValue),
           validateAXRect(rect, screenFrames: screenFrames, primaryScreenFrame: primaryScreenFrame) {
            return appKitRect(fromAXRect: rect, primaryScreenFrame: primaryScreenFrame)
        }

        guard let selectedRange = selectedRange(from: selectedRangeValue) else {
            return nil
        }

        guard selectedRange.length == 0, selectedRange.location > 0 else {
            return nil
        }

        var previousCharacterRange = CFRange(location: selectedRange.location - 1, length: 1)
        guard let previousRangeValue = AXValueCreate(.cfRange, &previousCharacterRange),
              let rect = boundsForRange(element: element, rangeValue: previousRangeValue),
              validateAXRect(rect, screenFrames: screenFrames, primaryScreenFrame: primaryScreenFrame)
        else {
            return nil
        }

        let appKitCharacterRect = appKitRect(fromAXRect: rect, primaryScreenFrame: primaryScreenFrame)
        return insertionPointRect(fromCharacterRect: appKitCharacterRect)
    }

    private static func queryViaTextMarker(
        _ element: AXUIElement,
        screenFrames: [CGRect],
        primaryScreenFrame: CGRect
    ) -> CGRect? {
        var markerRangeValue: CFTypeRef?
        let markerStatus = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextMarkerRangeAttribute as CFString,
            &markerRangeValue
        )

        guard markerStatus == .success, let markerRangeValue else {
            return nil
        }

        var boundsValue: CFTypeRef?
        let boundsStatus = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForTextMarkerRangeParameterizedAttribute as CFString,
            markerRangeValue,
            &boundsValue
        )

        guard
            boundsStatus == .success,
            let rect = cgRect(from: boundsValue),
            validateAXRect(rect, screenFrames: screenFrames, primaryScreenFrame: primaryScreenFrame)
        else {
            return nil
        }

        return appKitRect(fromAXRect: rect, primaryScreenFrame: primaryScreenFrame)
    }

    private static func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )

        guard
            status == .success,
            let focusedValue,
            CFGetTypeID(focusedValue) == AXUIElementGetTypeID()
        else {
            return nil
        }

        return (focusedValue as! AXUIElement)
    }

    private static func selectedRangeValue(from element: AXUIElement) -> AXValue? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &value
        )

        guard
            status == .success,
            let value,
            CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }

        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == .cfRange else {
            return nil
        }

        return axValue
    }

    private static func selectedRange(from value: AXValue) -> CFRange? {
        var range = CFRange(location: 0, length: 0)
        guard AXValueGetValue(value, .cfRange, &range) else {
            return nil
        }
        return range
    }

    private static func boundsForRange(element: AXUIElement, rangeValue: AXValue) -> CGRect? {
        var boundsValue: CFTypeRef?
        let status = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &boundsValue
        )

        guard status == .success else {
            return nil
        }

        return cgRect(from: boundsValue)
    }

    private static func cgRect(from value: CFTypeRef?) -> CGRect? {
        guard let value, CFGetTypeID(value) == AXValueGetTypeID() else {
            return nil
        }

        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == .cgRect else {
            return nil
        }

        var rect = CGRect.zero
        guard AXValueGetValue(axValue, .cgRect, &rect) else {
            return nil
        }

        return rect
    }
}
