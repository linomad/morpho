import Foundation
import XCTest
@testable import MorphoKit

final class LayeredTextContextGatewayTests: XCTestCase {
    func testCaptureUsesPrimaryGatewayWhenPrimarySucceeds() throws {
        let primaryToken = UUID()
        let primaryContext = TextContext(
            appBundleId: "com.apple.TextEdit",
            fullText: "hello",
            selectedRange: NSRange(location: 0, length: 5),
            selectedText: "hello",
            isSecureField: false,
            replacementToken: primaryToken
        )
        let primary = GatewayStub(captureResult: .success(primaryContext))
        let fallback = GatewayStub(captureResult: .failure(TranslationWorkflowError.unsupportedInputControl))
        let gateway = LayeredTextContextGateway(primaryGateway: primary, fallbackGateway: fallback)

        let context = try gateway.captureFocusedContext()
        try gateway.replace(in: context, with: "你好", mode: .selection)

        XCTAssertEqual(primary.captureCallCount, 1)
        XCTAssertEqual(fallback.captureCallCount, 0)
        XCTAssertEqual(primary.replaceCallCount, 1)
        XCTAssertEqual(fallback.replaceCallCount, 0)
        XCTAssertEqual(primary.lastReplaceContext?.replacementToken, primaryToken)
    }

    func testCaptureFallsBackWhenPrimaryReportsUnsupportedControl() throws {
        let fallbackToken = UUID()
        let fallbackContext = TextContext(
            appBundleId: "com.google.Chrome",
            fullText: "selected text",
            selectedRange: NSRange(location: 0, length: 13),
            selectedText: "selected text",
            isSecureField: false,
            replacementToken: fallbackToken
        )
        let primary = GatewayStub(captureResult: .failure(TranslationWorkflowError.unsupportedInputControl))
        let fallback = GatewayStub(captureResult: .success(fallbackContext))
        let gateway = LayeredTextContextGateway(primaryGateway: primary, fallbackGateway: fallback)

        let context = try gateway.captureFocusedContext()
        try gateway.replace(in: context, with: "翻译文本", mode: .selection)

        XCTAssertEqual(primary.captureCallCount, 1)
        XCTAssertEqual(fallback.captureCallCount, 1)
        XCTAssertEqual(primary.replaceCallCount, 0)
        XCTAssertEqual(fallback.replaceCallCount, 1)
        XCTAssertEqual(fallback.lastReplaceContext?.replacementToken, fallbackToken)
    }

    func testReplaceFailsWhenTokenCannotBeResolved() {
        let primary = GatewayStub(captureResult: .failure(TranslationWorkflowError.unsupportedInputControl))
        let fallback = GatewayStub(captureResult: .failure(TranslationWorkflowError.unsupportedInputControl))
        let gateway = LayeredTextContextGateway(primaryGateway: primary, fallbackGateway: fallback)
        let context = TextContext(
            appBundleId: "unknown",
            fullText: "",
            selectedRange: nil,
            selectedText: nil,
            isSecureField: false,
            replacementToken: UUID()
        )

        XCTAssertThrowsError(
            try gateway.replace(in: context, with: "anything", mode: .selection)
        ) { error in
            XCTAssertEqual(error as? TranslationWorkflowError, .replacementFailed)
        }
    }
}

private final class GatewayStub: TextContextProvider, TextReplacer {
    private let captureResult: Result<TextContext, Error>
    var captureCallCount = 0
    var replaceCallCount = 0
    var lastReplaceContext: TextContext?

    init(captureResult: Result<TextContext, Error>) {
        self.captureResult = captureResult
    }

    func captureFocusedContext() throws -> TextContext {
        captureCallCount += 1
        switch captureResult {
        case .success(let context):
            return context
        case .failure(let error):
            throw error
        }
    }

    func replace(in context: TextContext, with translatedText: String, mode: ReplacementMode) throws {
        replaceCallCount += 1
        lastReplaceContext = context
    }
}
