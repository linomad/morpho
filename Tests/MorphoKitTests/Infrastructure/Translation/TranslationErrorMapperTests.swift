import XCTest
import Translation
@testable import MorphoKit

final class TranslationErrorMapperTests: XCTestCase {
    func testMapsUnableToIdentifyLanguage() {
        let mapped = TranslationErrorMapper.map(.unableToIdentifyLanguage)

        XCTAssertEqual(mapped, .unableToIdentifyLanguage)
    }

    func testMapsNothingToTranslate() {
        let mapped = TranslationErrorMapper.map(.nothingToTranslate)

        XCTAssertEqual(mapped, .noTextToTranslate)
    }

    func testMapsUnsupportedPairing() {
        let mapped = TranslationErrorMapper.map(.unsupportedLanguagePairing)

        XCTAssertEqual(mapped, .unsupportedLanguagePairing)
    }

    func testMapsInternalErrorToGenericFailure() {
        let mapped = TranslationErrorMapper.map(.internalError)

        XCTAssertEqual(mapped, .translationFailed)
    }
}
