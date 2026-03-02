import XCTest
@testable import MorphoKit

final class TranslationErrorPresenterTests: XCTestCase {
    func testAccessibilityPermissionMessage() {
        let message = TranslationErrorPresenter.message(for: .accessibilityPermissionDenied)

        XCTAssertEqual(message, "需要辅助功能权限，已为你打开系统设置。")
    }

    func testUnsupportedInputMessage() {
        let message = TranslationErrorPresenter.message(for: .unsupportedInputControl)

        XCTAssertEqual(message, "当前输入控件不支持直接翻译。")
    }

    func testNoTextMessage() {
        let message = TranslationErrorPresenter.message(for: .noTextToTranslate)

        XCTAssertEqual(message, "没有可翻译的文本。")
    }
}
