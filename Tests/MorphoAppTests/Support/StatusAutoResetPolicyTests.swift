import XCTest
@testable import MorphoApp

final class StatusAutoResetPolicyTests: XCTestCase {
    func testShouldAutoResetForChineseTranslationCompleteMessage() {
        XCTAssertTrue(MorphoAppModel.shouldAutoResetMenuStatus(message: "翻译完成: hello"))
    }

    func testShouldAutoResetForChinesePolishCompleteMessage() {
        XCTAssertTrue(MorphoAppModel.shouldAutoResetMenuStatus(message: "润色完成: hello"))
    }

    func testShouldAutoResetForEnglishTranslationCompleteMessage() {
        XCTAssertTrue(MorphoAppModel.shouldAutoResetMenuStatus(message: "Translation Complete: hello"))
    }

    func testShouldAutoResetForEnglishPolishCompleteMessage() {
        XCTAssertTrue(MorphoAppModel.shouldAutoResetMenuStatus(message: "Polish Complete: hello"))
    }

    func testShouldNotAutoResetForNonCompletionMessage() {
        XCTAssertFalse(MorphoAppModel.shouldAutoResetMenuStatus(message: "准备就绪"))
    }
}
