import XCTest
@testable import MorphoKit

final class TranslationErrorPresenterAdditionalTests: XCTestCase {
    func testUnableToIdentifyMessage() {
        let message = TranslationErrorPresenter.message(for: .unableToIdentifyLanguage)

        XCTAssertEqual(message, "无法识别源语言，请在设置中固定源语言后重试。")
    }

    func testUnsupportedPairingMessage() {
        let message = TranslationErrorPresenter.message(for: .unsupportedLanguagePairing)

        XCTAssertEqual(message, "当前源语言与目标语言组合暂不支持。")
    }

    func testCloudCredentialMissingMessage() {
        let message = TranslationErrorPresenter.message(for: .cloudCredentialMissing)

        XCTAssertEqual(message, "请先在设置中填写 API Key。")
    }

    func testCloudAuthenticationFailedMessage() {
        let message = TranslationErrorPresenter.message(for: .cloudAuthenticationFailed)

        XCTAssertEqual(message, "API Key 校验失败，请检查后重试。")
    }

    func testCloudRateLimitedMessage() {
        let message = TranslationErrorPresenter.message(for: .cloudRateLimited)

        XCTAssertEqual(message, "请求过于频繁，请稍后重试。")
    }

    func testCloudServiceUnavailableMessage() {
        let message = TranslationErrorPresenter.message(for: .cloudServiceUnavailable)

        XCTAssertEqual(message, "翻译服务暂时不可用，请稍后重试。")
    }

    func testSelectionRequiredMessage() {
        let message = TranslationErrorPresenter.message(for: .selectionRequiredForCurrentControl)

        XCTAssertEqual(message, "当前控件请先选中文本后翻译。")
    }
}
