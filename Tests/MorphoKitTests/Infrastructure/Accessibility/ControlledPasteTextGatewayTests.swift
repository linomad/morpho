import AppKit
import Foundation
import XCTest
@testable import MorphoKit

final class ControlledPasteTextGatewayTests: XCTestCase {
    func testCaptureAndReplaceRestoreClipboardContent() throws {
        let pasteboard = PasteboardFake(initialString: "clipboard-original")
        let keyboard = KeyboardSpy()
        var pastedValue: String?
        keyboard.onTrigger = { shortcut in
            switch shortcut {
            case .copy:
                pasteboard.simulateCopySelection("selected text")
            case .paste:
                pastedValue = pasteboard.readString()
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
        try gateway.replace(in: context, with: "translated text", mode: .selection)

        XCTAssertEqual(context.selectedText, "selected text")
        XCTAssertEqual(pastedValue, "translated text")
        XCTAssertEqual(pasteboard.currentString, "clipboard-original")
    }

    func testCaptureFailsWhenNoSelectionCanBeCopied() {
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
            XCTAssertEqual(error as? TranslationWorkflowError, .selectionRequiredForCurrentControl)
        }
        XCTAssertEqual(pasteboard.currentString, "clipboard-original")
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
}

private final class KeyboardSpy: KeyboardEventInjecting {
    var onTrigger: ((KeyboardShortcut) -> Void)?

    func trigger(_ shortcut: KeyboardShortcut) throws {
        onTrigger?(shortcut)
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
        currentString
    }

    func writeString(_ value: String) {
        let item = NSPasteboardItem()
        item.setString(value, forType: .string)
        items = [item]
        changeCount += 1
    }

    func simulateCopySelection(_ value: String) {
        writeString(value)
    }
}
