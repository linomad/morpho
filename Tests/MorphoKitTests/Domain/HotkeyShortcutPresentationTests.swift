import XCTest
@testable import MorphoKit

final class HotkeyShortcutPresentationTests: XCTestCase {
    func testSummaryFormatsShortcutWithModifiers() {
        let shortcut = HotkeyShortcut(keyCode: 17, modifiers: [.command, .option])
        XCTAssertEqual(HotkeyShortcutPresentation.summary(for: shortcut), "⌘⌥T")
    }

    func testSummaryFallsBackToKeyCodeWhenUnknown() {
        let shortcut = HotkeyShortcut(keyCode: 999, modifiers: [.shift])
        XCTAssertEqual(HotkeyShortcutPresentation.summary(for: shortcut), "⇧KeyCode(999)")
    }

    func testBuildRejectsModifierKeys() {
        let shortcut = HotkeyShortcutPresentation.build(
            keyCode: 55,
            modifiers: [.command]
        )
        XCTAssertNil(shortcut)
    }

    func testBuildRejectsWhenNoModifierPressed() {
        let shortcut = HotkeyShortcutPresentation.build(
            keyCode: 17,
            modifiers: []
        )
        XCTAssertNil(shortcut)
    }

    func testBuildReturnsShortcutForValidCombination() {
        let shortcut = HotkeyShortcutPresentation.build(
            keyCode: 17,
            modifiers: [.option, .shift]
        )
        XCTAssertEqual(shortcut, HotkeyShortcut(keyCode: 17, modifiers: [.option, .shift]))
    }
}
