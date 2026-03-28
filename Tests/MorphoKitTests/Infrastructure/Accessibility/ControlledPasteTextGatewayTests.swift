import AppKit
import Foundation
import XCTest
@testable import MorphoKit

final class ControlledPasteTextGatewayTests: XCTestCase {
    func testCaptureAndReplaceRestoreClipboardContent() throws {
        let pasteboard = PasteboardFake(initialString: "clipboard-original")
        let keyboard = KeyboardSpy()
        keyboard.onTrigger = { shortcut in
            switch shortcut {
            case .selectAll:
                break
            case .copy:
                pasteboard.simulateCopySelection("selected text")
            case .paste:
                break
            }
        }

        let gateway = ControlledPasteTextGateway(
            keyboard: keyboard,
            pasteboard: pasteboard,
            focusedAppBundleIdProvider: { "com.google.Chrome" },
            secureFieldDetector: { false },
            copyPollingAttempts: 1,
            copyPollingInterval: 0,
            pasteSettleInterval: 0
        )

        let context = try gateway.captureFocusedContext()
        try gateway.replace(in: context, with: "translated text", mode: .selection)

        XCTAssertEqual(context.selectedText, "selected text")
        XCTAssertEqual(keyboard.triggeredShortcuts, [.copy, .paste])
        XCTAssertEqual(pasteboard.currentString, "clipboard-original")
    }

    func testCaptureReadsEntireFieldWhenSelectionIsMissing() throws {
        let pasteboard = PasteboardFake(initialString: "clipboard-original")
        let keyboard = KeyboardSpy()
        var didSelectAll = false

        keyboard.onTrigger = { shortcut in
            switch shortcut {
            case .copy:
                if didSelectAll {
                    pasteboard.simulateCopySelection("full input content")
                }
            case .selectAll:
                didSelectAll = true
            case .paste:
                break
            }
        }

        let gateway = ControlledPasteTextGateway(
            keyboard: keyboard,
            pasteboard: pasteboard,
            focusedAppBundleIdProvider: { "com.google.Chrome" },
            secureFieldDetector: { false },
            copyPollingAttempts: 1,
            copyPollingInterval: 0
        )

        let context = try gateway.captureFocusedContext()

        XCTAssertEqual(context.fullText, "full input content")
        XCTAssertNil(context.selectedText)
        XCTAssertNil(context.selectedRange)
        XCTAssertEqual(
            keyboard.triggeredShortcuts,
            [.copy, .selectAll, .copy]
        )
        XCTAssertEqual(pasteboard.currentString, "clipboard-original")
    }

    func testReplaceEntireFieldTriggersSelectAllBeforePaste() throws {
        let pasteboard = PasteboardFake(initialString: "clipboard-original")
        let keyboard = KeyboardSpy()
        var didSelectAll = false

        keyboard.onTrigger = { shortcut in
            switch shortcut {
            case .copy:
                if didSelectAll {
                    pasteboard.simulateCopySelection("full input content")
                }
            case .selectAll:
                didSelectAll = true
            case .paste:
                break
            }
        }

        let gateway = ControlledPasteTextGateway(
            keyboard: keyboard,
            pasteboard: pasteboard,
            focusedAppBundleIdProvider: { "com.google.Chrome" },
            secureFieldDetector: { false },
            copyPollingAttempts: 1,
            copyPollingInterval: 0,
            pasteSettleInterval: 0
        )

        let context = try gateway.captureFocusedContext()
        try gateway.replace(in: context, with: "translated text", mode: .entireField)

        XCTAssertEqual(
            keyboard.triggeredShortcuts,
            [.copy, .selectAll, .copy, .selectAll, .paste]
        )
        XCTAssertEqual(pasteboard.currentString, "clipboard-original")
    }

    func testCaptureFailsWhenCopyOnlyEchoesCurrentClipboardValue() {
        let pasteboard = PasteboardFake(initialString: "handleCategoryChange")
        let keyboard = KeyboardSpy()

        keyboard.onTrigger = { shortcut in
            switch shortcut {
            case .copy:
                // Simulate controls that only mirror current pasteboard content.
                pasteboard.simulateCopySelection(pasteboard.readString() ?? "")
            case .selectAll:
                break
            case .paste:
                break
            }
        }

        let gateway = ControlledPasteTextGateway(
            keyboard: keyboard,
            pasteboard: pasteboard,
            focusedAppBundleIdProvider: { "com.openai.codex" },
            secureFieldDetector: { false },
            copyPollingAttempts: 1,
            copyPollingInterval: 0
        )

        XCTAssertThrowsError(try gateway.captureFocusedContext()) { error in
            XCTAssertEqual(error as? TranslationWorkflowError, .unsupportedInputControl)
        }
        XCTAssertEqual(
            keyboard.triggeredShortcuts,
            [.copy, .selectAll, .copy]
        )
        XCTAssertEqual(pasteboard.currentString, "handleCategoryChange")
    }

    func testCaptureFailsWhenTextCannotBeCopied() {
        let pasteboard = PasteboardFake(initialString: "clipboard-original")
        let keyboard = KeyboardSpy()
        keyboard.onTrigger = { _ in }

        let gateway = ControlledPasteTextGateway(
            keyboard: keyboard,
            pasteboard: pasteboard,
            focusedAppBundleIdProvider: { "com.google.Chrome" },
            secureFieldDetector: { false },
            copyPollingAttempts: 1,
            copyPollingInterval: 0
        )

        XCTAssertThrowsError(try gateway.captureFocusedContext()) { error in
            XCTAssertEqual(error as? TranslationWorkflowError, .unsupportedInputControl)
        }
        XCTAssertEqual(pasteboard.currentString, "clipboard-original")
        XCTAssertEqual(
            keyboard.triggeredShortcuts,
            [.copy, .selectAll, .copy]
        )
    }

    func testCaptureWaitsForSelectAllToSettleBeforeCopyingEntireField() throws {
        let pasteboard = PasteboardFake(initialString: "clipboard-original")
        let keyboard = KeyboardSpy()
        var didSelectAll = false
        var sleepIntervals: [TimeInterval] = []

        keyboard.onTrigger = { shortcut in
            switch shortcut {
            case .copy:
                if didSelectAll {
                    pasteboard.simulateCopySelection("full input content")
                }
            case .selectAll:
                didSelectAll = true
            case .paste:
                break
            }
        }

        let gateway = ControlledPasteTextGateway(
            keyboard: keyboard,
            pasteboard: pasteboard,
            focusedAppBundleIdProvider: { "com.google.Chrome" },
            secureFieldDetector: { false },
            copyPollingAttempts: 1,
            copyPollingInterval: 0,
            selectAllSettleInterval: 0.03,
            sleep: { interval in
                sleepIntervals.append(interval)
            }
        )

        let context = try gateway.captureFocusedContext()

        XCTAssertEqual(context.fullText, "full input content")
        XCTAssertEqual(sleepIntervals, [0.03])
    }

    func testReplaceFailsWhenFocusedApplicationChanges() throws {
        let pasteboard = PasteboardFake(initialString: "clipboard-original")
        let keyboard = KeyboardSpy()
        keyboard.onTrigger = { shortcut in
            if shortcut == .copy {
                pasteboard.simulateCopySelection("selected text")
            }
        }

        var focusedAppBundleId = "com.google.Chrome"
        let gateway = ControlledPasteTextGateway(
            keyboard: keyboard,
            pasteboard: pasteboard,
            focusedAppBundleIdProvider: { focusedAppBundleId },
            secureFieldDetector: { false },
            copyPollingAttempts: 1,
            copyPollingInterval: 0
        )

        let context = try gateway.captureFocusedContext()
        focusedAppBundleId = "com.tinyspeck.slackmacgap"

        XCTAssertThrowsError(try gateway.replace(in: context, with: "translated text", mode: .selection)) { error in
            XCTAssertEqual(error as? TranslationWorkflowError, .focusedInputUnavailable)
        }
        XCTAssertEqual(pasteboard.currentString, "clipboard-original")
    }

    func testReplacePastesTranslatedTextAndRestoresClipboard() throws {
        let pasteboard = PasteboardFake(initialString: "clipboard-original")
        let keyboard = KeyboardSpy()

        keyboard.onTrigger = { shortcut in
            if shortcut == .copy {
                pasteboard.simulateCopySelection("selected text")
            }
        }

        let gateway = ControlledPasteTextGateway(
            keyboard: keyboard,
            pasteboard: pasteboard,
            focusedAppBundleIdProvider: { "com.google.Chrome" },
            secureFieldDetector: { false },
            copyPollingAttempts: 1,
            copyPollingInterval: 0,
            pasteSettleInterval: 0
        )

        let context = try gateway.captureFocusedContext()
        try gateway.replace(in: context, with: "translated text", mode: .selection)

        XCTAssertEqual(keyboard.triggeredShortcuts, [.copy, .paste])
        XCTAssertEqual(pasteboard.currentString, "clipboard-original")
    }
}

private final class KeyboardSpy: KeyboardEventInjecting {
    var onTrigger: ((KeyboardShortcut) -> Void)?
    private(set) var triggeredShortcuts: [KeyboardShortcut] = []
    private(set) var insertedTexts: [String] = []

    func trigger(_ shortcut: KeyboardShortcut) throws {
        triggeredShortcuts.append(shortcut)
        onTrigger?(shortcut)
    }

    func insertText(_ text: String) throws {
        insertedTexts.append(text)
    }
}

private final class PasteboardFake: PasteboardAccessing {
    private var items: [NSPasteboardItem]
    private(set) var changeCount: Int

    init(initialString: String?) {
        if let initialString {
            let item = NSPasteboardItem()
            item.setString(initialString, forType: .string)
            self.items = [item]
        } else {
            self.items = []
        }
        self.changeCount = 0
    }

    var currentString: String? {
        items.first?.string(forType: .string)
    }

    func snapshot() -> PasteboardSnapshot {
        let snapshots = items.map { item in
            var payloads: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    payloads[type] = data
                }
            }
            return PasteboardItemSnapshot(payloads: payloads)
        }

        return PasteboardSnapshot(items: snapshots, changeCount: changeCount)
    }

    func restore(_ snapshot: PasteboardSnapshot) {
        items = snapshot.items.map { snapshot in
            let item = NSPasteboardItem()
            for (type, data) in snapshot.payloads {
                item.setData(data, forType: type)
            }
            return item
        }
        changeCount += 1
    }

    func readString() -> String? {
        return currentString
    }

    func writeString(_ value: String) {
        let item = NSPasteboardItem()
        item.setString(value, forType: .string)
        items = [item]
        changeCount += 1
    }

    func writeStringTransient(_ value: String) {
        writeString(value)
    }

    func simulateCopySelection(_ value: String) {
        writeString(value)
    }
}
