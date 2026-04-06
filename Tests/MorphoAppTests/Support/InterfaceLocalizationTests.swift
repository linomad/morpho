import Foundation
import XCTest
@testable import MorphoApp

final class InterfaceLocalizationTests: XCTestCase {
    func testSettingsGeneralTabUsesEnglishTranslation() {
        let value = AppLocalization.string("settings.tab.general", locale: Locale(identifier: "en"))

        XCTAssertEqual(value, "General")
    }

    func testSettingsGeneralTabUsesSimplifiedChineseTranslation() {
        let value = AppLocalization.string("settings.tab.general", locale: Locale(identifier: "zh-Hans"))

        XCTAssertEqual(value, "通用")
    }

    func testMenuSettingsActionUsesEnglishTranslation() {
        let value = AppLocalization.string("menu.action.settings", locale: Locale(identifier: "en"))

        XCTAssertEqual(value, "Settings")
    }

    func testMenuModePolishUsesEnglishTranslation() {
        let value = AppLocalization.string("menu.mode.polish", locale: Locale(identifier: "en"))

        XCTAssertEqual(value, "Polish")
    }

    func testPolishStatusUsesSimplifiedChineseTranslation() {
        let value = AppLocalization.string("status.polish_complete", locale: Locale(identifier: "zh-Hans"))

        XCTAssertEqual(value, "润色完成")
    }
}
