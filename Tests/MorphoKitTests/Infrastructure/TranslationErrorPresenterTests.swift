import XCTest
@testable import MorphoKit

final class TranslationErrorPresenterTests: XCTestCase {
    func testAccessibilityPermissionDescriptor() {
        let descriptor = TranslationErrorPresenter.descriptor(for: .accessibilityPermissionDenied)

        XCTAssertEqual(descriptor.key, "error.accessibility_permission_denied")
        XCTAssertTrue(descriptor.args.isEmpty)
    }

    func testUnsupportedInputDescriptor() {
        let descriptor = TranslationErrorPresenter.descriptor(for: .unsupportedInputControl)

        XCTAssertEqual(descriptor.key, "error.unsupported_input_control")
        XCTAssertTrue(descriptor.args.isEmpty)
    }

    func testNoTextDescriptor() {
        let descriptor = TranslationErrorPresenter.descriptor(for: .noTextToTranslate)

        XCTAssertEqual(descriptor.key, "error.no_text_to_translate")
        XCTAssertTrue(descriptor.args.isEmpty)
    }

    func testInputTextTooLongDescriptor() {
        let descriptor = TranslationErrorPresenter.descriptor(for: .inputTextTooLong(actualCount: 10000, maxCount: 5000))

        XCTAssertEqual(descriptor.key, "error.input_text_too_long")
        XCTAssertEqual(descriptor.args, ["10000", "5000"])
    }
}
