import AppKit
import ApplicationServices
import Foundation

public final class ControlledPasteTextGateway: TextContextProvider, TextReplacer {
    private struct Session {
        let appBundleId: String
    }

    private let keyboard: any KeyboardEventInjecting
    private let pasteboard: any PasteboardAccessing
    private let focusedAppBundleIdProvider: () -> String?
    private let secureFieldDetector: () -> Bool
    private let copyPollingAttempts: Int
    private let copyPollingInterval: TimeInterval

    private var sessions: [UUID: Session] = [:]

    public init() {
        self.keyboard = SystemKeyboardEventInjector()
        self.pasteboard = SystemPasteboardAccessor()
        self.focusedAppBundleIdProvider = { SystemFocusInspector.focusedAppBundleId() }
        self.secureFieldDetector = { SystemFocusInspector.isFocusedSecureField() }
        self.copyPollingAttempts = 12
        self.copyPollingInterval = 0.01
    }

    init(
        keyboard: any KeyboardEventInjecting,
        pasteboard: any PasteboardAccessing,
        focusedAppBundleIdProvider: @escaping () -> String?,
        secureFieldDetector: @escaping () -> Bool,
        copyPollingAttempts: Int = 12,
        copyPollingInterval: TimeInterval = 0.01
    ) {
        self.keyboard = keyboard
        self.pasteboard = pasteboard
        self.focusedAppBundleIdProvider = focusedAppBundleIdProvider
        self.secureFieldDetector = secureFieldDetector
        self.copyPollingAttempts = copyPollingAttempts
        self.copyPollingInterval = copyPollingInterval
    }

    public func captureFocusedContext() throws -> TextContext {
        guard let appBundleId = focusedAppBundleIdProvider() else {
            throw TranslationWorkflowError.focusedInputUnavailable
        }

        guard !secureFieldDetector() else {
            return TextContext(
                appBundleId: appBundleId,
                fullText: "",
                selectedRange: nil,
                selectedText: nil,
                isSecureField: true,
                replacementToken: nil
            )
        }

        let selectedText = try captureSelectedText()
        let token = UUID()
        sessions[token] = Session(appBundleId: appBundleId)

        return TextContext(
            appBundleId: appBundleId,
            fullText: selectedText,
            selectedRange: NSRange(location: 0, length: (selectedText as NSString).length),
            selectedText: selectedText,
            isSecureField: false,
            replacementToken: token
        )
    }

    public func replace(in context: TextContext, with translatedText: String, mode: ReplacementMode) throws {
        guard let token = context.replacementToken, let session = sessions[token] else {
            throw TranslationWorkflowError.replacementFailed
        }
        defer {
            sessions[token] = nil
        }

        guard focusedAppBundleIdProvider() == session.appBundleId else {
            throw TranslationWorkflowError.focusedInputUnavailable
        }

        let snapshot = pasteboard.snapshot()
        defer {
            pasteboard.restore(snapshot)
        }

        pasteboard.writeString(translatedText)
        do {
            try keyboard.trigger(.paste)
        } catch {
            throw TranslationWorkflowError.replacementFailed
        }
    }

    private func captureSelectedText() throws -> String {
        let snapshot = pasteboard.snapshot()
        defer {
            pasteboard.restore(snapshot)
        }

        do {
            try keyboard.trigger(.copy)
        } catch {
            throw TranslationWorkflowError.focusedInputUnavailable
        }

        guard let copiedText = readCopiedSelection(afterChangeCount: snapshot.changeCount) else {
            throw TranslationWorkflowError.selectionRequiredForCurrentControl
        }

        let trimmedText = copiedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw TranslationWorkflowError.selectionRequiredForCurrentControl
        }

        return copiedText
    }

    private func readCopiedSelection(afterChangeCount baselineChangeCount: Int) -> String? {
        for _ in 0..<copyPollingAttempts {
            if pasteboard.changeCount > baselineChangeCount {
                return pasteboard.readString()
            }

            Thread.sleep(forTimeInterval: copyPollingInterval)
        }

        if pasteboard.changeCount > baselineChangeCount {
            return pasteboard.readString()
        }

        return nil
    }
}

private enum SystemFocusInspector {
    static func focusedAppBundleId() -> String? {
        guard let focusedElement = focusedElement() else {
            return nil
        }

        var pid: pid_t = 0
        AXUIElementGetPid(focusedElement, &pid)
        return NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
    }

    static func isFocusedSecureField() -> Bool {
        guard let focusedElement = focusedElement() else {
            return false
        }

        var current: AXUIElement? = focusedElement
        var depth = 0

        while let element = current, depth < 8 {
            if role(of: element) == "AXSecureTextField" {
                return true
            }

            current = parent(of: element)
            depth += 1
        }

        return false
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

    private static func parent(of element: AXUIElement) -> AXUIElement? {
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

    private static func role(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            element,
            kAXRoleAttribute as CFString,
            &value
        )

        guard status == .success else {
            return nil
        }

        return AXAttributeStringDecoder.decode(value)
    }
}
