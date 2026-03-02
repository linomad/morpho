import AppKit
import ApplicationServices
import Foundation

public final class AXTextContextGateway: TextContextProvider, TextReplacer {
    private struct ResolvedTextElement {
        let element: AXUIElement
        let fullText: String
        let selectedText: String?
        let selectedRange: NSRange?
        let role: String?
    }

    private var focusedElements: [UUID: AXUIElement] = [:]

    public init() {}

    public func captureFocusedContext() throws -> TextContext {
        let focused = try focusedElement()
        let resolved = try resolveTextElement(from: focused)

        let token = UUID()
        focusedElements[token] = resolved.element

        let isSecureField = resolved.role == "AXSecureTextField"

        return TextContext(
            appBundleId: bundleIdentifier(for: resolved.element),
            fullText: resolved.fullText,
            selectedRange: resolved.selectedRange,
            selectedText: resolved.selectedText,
            isSecureField: isSecureField,
            replacementToken: token
        )
    }

    public func replace(in context: TextContext, with translatedText: String, mode: ReplacementMode) throws {
        guard let token = context.replacementToken, let storedElement = focusedElements[token] else {
            throw TranslationWorkflowError.replacementFailed
        }

        let currentFocused = try focusedElement()
        let currentResolved = try resolveTextElement(from: currentFocused)

        guard CFEqual(currentResolved.element, storedElement) else {
            throw TranslationWorkflowError.focusedInputUnavailable
        }

        let status: AXError
        switch mode {
        case .selection:
            status = AXUIElementSetAttributeValue(
                storedElement,
                kAXSelectedTextAttribute as CFString,
                translatedText as CFTypeRef
            )
        case .entireField:
            status = AXUIElementSetAttributeValue(
                storedElement,
                kAXValueAttribute as CFString,
                translatedText as CFTypeRef
            )
        }

        guard status == .success else {
            throw TranslationWorkflowError.replacementFailed
        }

        focusedElements[token] = nil
    }

    private func resolveTextElement(from start: AXUIElement) throws -> ResolvedTextElement {
        var current: AXUIElement? = start
        var visited = 0

        while let element = current, visited < 12 {
            if let resolved = buildResolvedTextElement(for: element) {
                return resolved
            }

            current = parent(of: element)
            visited += 1
        }

        throw TranslationWorkflowError.unsupportedInputControl
    }

    private func buildResolvedTextElement(for element: AXUIElement) -> ResolvedTextElement? {
        let fullText = readTextAttribute(kAXValueAttribute, from: element)
        guard let fullText, !fullText.isEmpty else {
            return nil
        }

        guard isWritableTextElement(element) else {
            return nil
        }

        return ResolvedTextElement(
            element: element,
            fullText: fullText,
            selectedText: readTextAttribute(kAXSelectedTextAttribute, from: element),
            selectedRange: readSelectedRange(from: element),
            role: readTextAttribute(kAXRoleAttribute, from: element)
        )
    }

    private func isWritableTextElement(_ element: AXUIElement) -> Bool {
        var valueSettable = DarwinBoolean(false)
        let valueStatus = AXUIElementIsAttributeSettable(
            element,
            kAXValueAttribute as CFString,
            &valueSettable
        )

        var selectedTextSettable = DarwinBoolean(false)
        let selectedTextStatus = AXUIElementIsAttributeSettable(
            element,
            kAXSelectedTextAttribute as CFString,
            &selectedTextSettable
        )

        if valueStatus == .success, valueSettable.boolValue {
            return true
        }

        if selectedTextStatus == .success, selectedTextSettable.boolValue {
            return true
        }

        return false
    }

    private func focusedElement() throws -> AXUIElement {
        let systemWide = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?

        let status = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )

        guard status == .success, let focusedValue, CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
            throw TranslationWorkflowError.focusedInputUnavailable
        }

        return (focusedValue as! AXUIElement)
    }

    private func parent(of element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            element,
            kAXParentAttribute as CFString,
            &value
        )

        guard status == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }

        return (value as! AXUIElement)
    }

    private func readTextAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?

        let status = AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        )

        guard status == .success else {
            return nil
        }

        return AXAttributeStringDecoder.decode(value)
    }

    private func readSelectedRange(from element: AXUIElement) -> NSRange? {
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

        var range = CFRange(location: 0, length: 0)
        guard AXValueGetValue(axValue, .cfRange, &range) else {
            return nil
        }

        return NSRange(location: range.location, length: range.length)
    }

    private func bundleIdentifier(for element: AXUIElement) -> String {
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)

        return NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? "unknown"
    }
}
