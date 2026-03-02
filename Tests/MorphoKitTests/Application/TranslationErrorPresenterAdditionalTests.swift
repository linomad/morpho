import XCTest
@testable import MorphoKit

final class TranslationErrorPresenterAdditionalTests: XCTestCase {
    func testUnableToIdentifyMessage() {
        let message = TranslationErrorPresenter.message(for: .unableToIdentifyLanguage)

        XCTAssertEqual(message, "无法识别源语言，请在设置中固定源语言后重试。")
    }

    func testUnsupportedPairingMessage() {
        let message = TranslationErrorPresenter.message(for: .unsupportedLanguagePairing)

        XCTAssertEqual(message, "当前源语言与目标语言组合不受系统翻译支持。")
    }

    func testTranslationInProgressMessage() {
        let message = TranslationErrorPresenter.message(for: .translationInProgress)

        XCTAssertEqual(message, "翻译进行中，请稍后再试。")
    }

    func testTranslationInterruptedMessage() {
        let message = TranslationErrorPresenter.message(for: .translationInterrupted)

        XCTAssertEqual(message, "翻译过程被中断，请重试。")
    }

    func testTranslationSessionStartupTimeoutMessage() {
        let message = TranslationErrorPresenter.message(for: .translationSessionStartupTimeout)

        XCTAssertEqual(message, "系统翻译服务启动超时，请重试。")
    }
}
