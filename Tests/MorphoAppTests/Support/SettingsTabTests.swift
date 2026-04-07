import Foundation
import XCTest
@testable import MorphoApp

final class SettingsTabTests: XCTestCase {
    func testAllCasesContainModeTabAndDropLegacyLanguageAndEngineTabs() {
        XCTAssertEqual(
            SettingsTab.allCases,
            [.general, .hotkey, .mode, .history, .about]
        )
    }

    func testModeTabUsesExpectedIcon() {
        XCTAssertEqual(SettingsTab.mode.iconName, "arrow.triangle.swap")
    }

    func testModeTabUsesEnglishTranslation() {
        let value = SettingsTab.mode.title(locale: Locale(identifier: "en"))

        XCTAssertEqual(value, "Mode")
    }

    func testModeTabUsesSimplifiedChineseTranslation() {
        let value = SettingsTab.mode.title(locale: Locale(identifier: "zh-Hans"))

        XCTAssertEqual(value, "模式")
    }
}
