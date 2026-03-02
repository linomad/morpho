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

    private let maxParentDepth = 20
    private let maxChildSearchDepth = 2
    private var focusedElements: [UUID: AXUIElement] = [:]

    public init() {}

    public func captureFocusedContext() throws -> TextContext {
        let focused = try focusedElement()
        let resolved = try resolveTextElement(from: focused)

        let isSecureField = resolved.role == "AXSecureTextField"
        if isSecureField {
            return TextContext(
                appBundleId: bundleIdentifier(for: resolved.element),
                fullText: resolved.fullText,
                selectedRange: resolved.selectedRange,
                selectedText: resolved.selectedText,
                isSecureField: true,
                replacementToken: nil
            )
        }

        let token = UUID()
        focusedElements[token] = resolved.element

        return TextContext(
            appBundleId: bundleIdentifier(for: resolved.element),
            fullText: resolved.fullText,
            selectedRange: resolved.selectedRange,
            selectedText: resolved.selectedText,
            isSecureField: false,
            replacementToken: token
        )
    }

    public func replace(in context: TextContext, with translatedText: String, mode: ReplacementMode) throws {
        guard let token = context.replacementToken, let storedElement = focusedElements[token] else {
            throw TranslationWorkflowError.replacementFailed
        }
        defer {
            focusedElements[token] = nil
        }

        let currentFocused = try focusedElement()
        guard areElementsInSameFocusChain(currentFocused, storedElement) else {
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
    }

    private func resolveTextElement(from start: AXUIElement) throws -> ResolvedTextElement {
        if let resolved = resolveInParentChain(from: start, maxDepth: maxParentDepth) {
            return resolved
        }

        if let resolved = resolveInDescendants(from: start, maxDepth: maxChildSearchDepth) {
            return resolved
        }

        throw TranslationWorkflowError.unsupportedInputControl
    }

    private func resolveInParentChain(
        from start: AXUIElement,
        maxDepth: Int
    ) -> ResolvedTextElement? {
        var current: AXUIElement? = start
        var visited = 0

        while let element = current, visited <= maxDepth {
            if let resolved = buildResolvedTextElement(for: element) {
                return resolved
            }

            current = parent(of: element)
            visited += 1
        }

        return nil
    }

    private func resolveInDescendants(
        from start: AXUIElement,
        maxDepth: Int
    ) -> ResolvedTextElement? {
        guard maxDepth > 0 else {
            return nil
        }

        var queue: [(element: AXUIElement, depth: Int)] = [(start, 0)]

        while !queue.isEmpty {
            let node = queue.removeFirst()
            let element = node.element
            let depth = node.depth

            if depth > 0, let resolved = buildResolvedTextElement(for: element) {
                return resolved
            }

            guard depth < maxDepth else {
                continue
            }

            for child in children(of: element) {
                queue.append((child, depth + 1))
            }
        }

        return nil
    }

    private func buildResolvedTextElement(for element: AXUIElement) -> ResolvedTextElement? {
        guard isWritableTextElement(element), isReadableTextElement(element) else {
            return nil
        }

        let fullText = readTextAttribute(kAXValueAttribute, from: element)
            ?? readTextAttribute(kAXSelectedTextAttribute, from: element)
            ?? ""

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

    private func isReadableTextElement(_ element: AXUIElement) -> Bool {
        if readTextAttribute(kAXValueAttribute, from: element) != nil {
            return true
        }

        if readTextAttribute(kAXSelectedTextAttribute, from: element) != nil {
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

    private func areElementsInSameFocusChain(_ lhs: AXUIElement, _ rhs: AXUIElement) -> Bool {
        if CFEqual(lhs, rhs) {
            return true
        }

        if isElement(rhs, inParentChainOf: lhs, maxDepth: maxParentDepth) {
            return true
        }

        if isElement(lhs, inParentChainOf: rhs, maxDepth: maxParentDepth) {
            return true
        }

        return false
    }

    private func isElement(
        _ target: AXUIElement,
        inParentChainOf start: AXUIElement,
        maxDepth: Int
    ) -> Bool {
        var current: AXUIElement? = start
        var depth = 0

        while let element = current, depth <= maxDepth {
            if CFEqual(element, target) {
                return true
            }

            current = parent(of: element)
            depth += 1
        }

        return false
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

    private func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            element,
            kAXChildrenAttribute as CFString,
            &value
        )

        guard status == .success, let value else {
            return []
        }

        guard let array = value as? [Any] else {
            return []
        }

        return array.compactMap { item in
            let candidate = item as CFTypeRef
            guard CFGetTypeID(candidate) == AXUIElementGetTypeID() else {
                return nil
            }

            return (candidate as! AXUIElement)
        }
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
