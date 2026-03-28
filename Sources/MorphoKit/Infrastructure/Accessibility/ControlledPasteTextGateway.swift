import AppKit
import ApplicationServices
import Foundation

public final class ControlledPasteTextGateway: TextContextProvider, TextReplacer {
    private struct Session {
        let appBundleId: String
    }

    private struct CapturedText {
        enum Kind {
            case selection
            case entireField
        }

        let text: String
        let kind: Kind
    }

    private let keyboard: any KeyboardEventInjecting
    private let pasteboard: any PasteboardAccessing
    private let focusedAppBundleIdProvider: () -> String?
    private let secureFieldDetector: () -> Bool
    private let copyPollingAttempts: Int
    private let copyPollingInterval: TimeInterval
    private let selectAllSettleInterval: TimeInterval
    private let sleep: (TimeInterval) -> Void

    private var sessions: [UUID: Session] = [:]

    public init() {
        self.keyboard = SystemKeyboardEventInjector()
        self.pasteboard = SystemPasteboardAccessor()
        self.focusedAppBundleIdProvider = { SystemFocusInspector.focusedAppBundleId() }
        self.secureFieldDetector = { SystemFocusInspector.isFocusedSecureField() }
        self.copyPollingAttempts = 12
        self.copyPollingInterval = 0.01
        self.selectAllSettleInterval = 0.03
        self.sleep = { interval in
            Thread.sleep(forTimeInterval: interval)
        }
    }

    init(
        keyboard: any KeyboardEventInjecting,
        pasteboard: any PasteboardAccessing,
        focusedAppBundleIdProvider: @escaping () -> String?,
        secureFieldDetector: @escaping () -> Bool,
        copyPollingAttempts: Int = 12,
        copyPollingInterval: TimeInterval = 0.01,
        selectAllSettleInterval: TimeInterval = 0.03,
        sleep: @escaping (TimeInterval) -> Void = { interval in
            Thread.sleep(forTimeInterval: interval)
        }
    ) {
        self.keyboard = keyboard
        self.pasteboard = pasteboard
        self.focusedAppBundleIdProvider = focusedAppBundleIdProvider
        self.secureFieldDetector = secureFieldDetector
        self.copyPollingAttempts = copyPollingAttempts
        self.copyPollingInterval = copyPollingInterval
        self.selectAllSettleInterval = selectAllSettleInterval
        self.sleep = sleep
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

        let capturedText = try captureText()
        let token = UUID()
        sessions[token] = Session(appBundleId: appBundleId)

        let selectedText: String?
        let selectedRange: NSRange?

        switch capturedText.kind {
        case .selection:
            selectedText = capturedText.text
            selectedRange = NSRange(location: 0, length: (capturedText.text as NSString).length)
        case .entireField:
            selectedText = nil
            selectedRange = nil
        }

        return TextContext(
            appBundleId: appBundleId,
            fullText: capturedText.text,
            selectedRange: selectedRange,
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

        do {
            if mode == .entireField {
                try keyboard.trigger(.selectAll)
                wait(selectAllSettleInterval)
            }
            try keyboard.insertText(translatedText)
        } catch {
            throw TranslationWorkflowError.replacementFailed
        }
    }

    private func captureText() throws -> CapturedText {
        let snapshot = pasteboard.snapshot()
        defer {
            pasteboard.restore(snapshot)
        }

        if let selectedText = try copyText(selectAllBeforeCopy: false),
           isMeaningful(text: selectedText) {
            return CapturedText(text: selectedText, kind: .selection)
        }

        if let fullText = try copyText(selectAllBeforeCopy: true),
           isMeaningful(text: fullText) {
            return CapturedText(text: fullText, kind: .entireField)
        }

        throw TranslationWorkflowError.unsupportedInputControl
    }

    private func copyText(selectAllBeforeCopy: Bool) throws -> String? {
        let probeToken = "morpho-probe-\(UUID().uuidString)"
        pasteboard.writeString(probeToken)
        let baselineChangeCount = pasteboard.changeCount

        do {
            if selectAllBeforeCopy {
                try keyboard.trigger(.selectAll)
                wait(selectAllSettleInterval)
            }
            try keyboard.trigger(.copy)
        } catch {
            throw TranslationWorkflowError.focusedInputUnavailable
        }

        return readCopiedSelection(
            afterChangeCount: baselineChangeCount,
            probeToken: probeToken
        )
    }

    private func isMeaningful(text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func readCopiedSelection(
        afterChangeCount baselineChangeCount: Int,
        probeToken: String
    ) -> String? {
        for _ in 0..<copyPollingAttempts {
            if pasteboard.changeCount > baselineChangeCount {
                return validatedCopiedText(probeToken: probeToken)
            }

            wait(copyPollingInterval)
        }

        if pasteboard.changeCount > baselineChangeCount {
            return validatedCopiedText(probeToken: probeToken)
        }

        return nil
    }

    private func validatedCopiedText(probeToken: String) -> String? {
        guard let copied = pasteboard.readString(), copied != probeToken else {
            return nil
        }

        return copied
    }

    private func wait(_ interval: TimeInterval) {
        guard interval > 0 else {
            return
        }

        sleep(interval)
    }
}

private enum SystemFocusInspector {
    static func focusedAppBundleId() -> String? {
        if let focusedElement = focusedElement() {
            var pid: pid_t = 0
            AXUIElementGetPid(focusedElement, &pid)
            if let bundleIdentifier = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier {
                return bundleIdentifier
            }
        }

        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier
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
