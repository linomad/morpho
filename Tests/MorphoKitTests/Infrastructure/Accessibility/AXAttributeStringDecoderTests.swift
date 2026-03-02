import Foundation
import XCTest
@testable import MorphoKit

final class AXAttributeStringDecoderTests: XCTestCase {
    func testDecodeReturnsStringForCFString() {
        let value: CFTypeRef = "hello" as CFString

        let decoded = AXAttributeStringDecoder.decode(value)

        XCTAssertEqual(decoded, "hello")
    }

    func testDecodeReturnsStringForAttributedString() {
        let value: CFTypeRef = NSAttributedString(string: "browser address")

        let decoded = AXAttributeStringDecoder.decode(value)

        XCTAssertEqual(decoded, "browser address")
    }

    func testDecodeReturnsStringForURL() {
        let value: CFTypeRef = URL(string: "https://example.com/query")! as NSURL

        let decoded = AXAttributeStringDecoder.decode(value)

        XCTAssertEqual(decoded, "https://example.com/query")
    }

    func testDecodeReturnsNilForUnsupportedType() {
        let value: CFTypeRef = NSNumber(value: 42)

        let decoded = AXAttributeStringDecoder.decode(value)

        XCTAssertNil(decoded)
    }
}
