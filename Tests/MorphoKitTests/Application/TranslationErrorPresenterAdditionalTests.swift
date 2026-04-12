import XCTest
@testable import MorphoKit

final class TranslationErrorPresenterAdditionalTests: XCTestCase {
    func testUnableToIdentifyDescriptor() {
        let descriptor = TranslationErrorPresenter.descriptor(for: .unableToIdentifyLanguage)

        XCTAssertEqual(descriptor.key, "error.unable_to_identify_language")
        XCTAssertTrue(descriptor.args.isEmpty)
    }

    func testUnsupportedPairingDescriptor() {
        let descriptor = TranslationErrorPresenter.descriptor(for: .unsupportedLanguagePairing)

        XCTAssertEqual(descriptor.key, "error.unsupported_language_pair")
        XCTAssertTrue(descriptor.args.isEmpty)
    }

    func testCloudCredentialMissingDescriptor() {
        let descriptor = TranslationErrorPresenter.descriptor(for: .cloudCredentialMissing)

        XCTAssertEqual(descriptor.key, "error.cloud.credential_missing")
        XCTAssertTrue(descriptor.args.isEmpty)
    }

    func testCloudAuthenticationFailedDescriptor() {
        let descriptor = TranslationErrorPresenter.descriptor(for: .cloudAuthenticationFailed)

        XCTAssertEqual(descriptor.key, "error.cloud.auth_failed")
        XCTAssertTrue(descriptor.args.isEmpty)
    }

    func testCloudRateLimitedDescriptor() {
        let descriptor = TranslationErrorPresenter.descriptor(for: .cloudRateLimited)

        XCTAssertEqual(descriptor.key, "error.cloud.rate_limited")
        XCTAssertTrue(descriptor.args.isEmpty)
    }

    func testCloudServiceUnavailableDescriptor() {
        let descriptor = TranslationErrorPresenter.descriptor(for: .cloudServiceUnavailable)

        XCTAssertEqual(descriptor.key, "error.cloud.service_unavailable")
        XCTAssertTrue(descriptor.args.isEmpty)
    }

    func testSelectionRequiredDescriptor() {
        let descriptor = TranslationErrorPresenter.descriptor(for: .selectionRequiredForCurrentControl)

        XCTAssertEqual(descriptor.key, "error.selection_required")
        XCTAssertTrue(descriptor.args.isEmpty)
    }
}
