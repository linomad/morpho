import Foundation
import XCTest
@testable import MorphoKit

final class LanguageIdentifierCodecTests: XCTestCase {
    func testDisplayIdentifierMapsSimplifiedChineseToSupportedIdentifier() {
        let identifier = LanguageIdentifierCodec.displayIdentifier(
            for: Locale.Language(identifier: "zh-Hans"),
            supportedIdentifiers: ["en", "zh-Hans", "zh-Hant"]
        )

        XCTAssertEqual(identifier, "zh-Hans")
    }

    func testDisplayIdentifierMapsTraditionalChineseToSupportedIdentifier() {
        let identifier = LanguageIdentifierCodec.displayIdentifier(
            for: Locale.Language(identifier: "zh-Hant"),
            supportedIdentifiers: ["en", "zh-Hans", "zh-Hant"]
        )

        XCTAssertEqual(identifier, "zh-Hant")
    }

    func testDisplayIdentifierFallsBackToMinimalIdentifierWhenUnsupported() {
        let identifier = LanguageIdentifierCodec.displayIdentifier(
            for: Locale.Language(identifier: "pl"),
            supportedIdentifiers: ["en", "zh-Hans", "zh-Hant"]
        )

        XCTAssertEqual(identifier, "pl")
    }
}
