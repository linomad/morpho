import Foundation
import XCTest
@testable import MorphoKit

final class CloudTranslationEngineTests: XCTestCase {
    func testTranslateFailsWhenAPIKeyMissing() async {
        let client = CloudTranslationProviderClientStub()
        let engine = CloudTranslationEngine(
            client: client
        )

        do {
            _ = try await engine.translate(
                "hello",
                source: .auto,
                target: Locale.Language(identifier: "zh-Hans"),
                apiKey: ""
            )
            XCTFail("Expected error")
        } catch let error as TranslationWorkflowError {
            XCTAssertEqual(error, .cloudCredentialMissing)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTranslateUsesCredentialAndReturnsProviderResult() async throws {
        let client = CloudTranslationProviderClientStub(result: "你好")
        let engine = CloudTranslationEngine(
            client: client
        )

        let output = try await engine.translate(
            "hello",
            source: .auto,
            target: Locale.Language(identifier: "zh-Hans"),
            apiKey: "sk-test"
        )

        XCTAssertEqual(output, "你好")
        XCTAssertEqual(client.lastAPIKey, "sk-test")
        XCTAssertEqual(client.lastText, "hello")
    }
}

private final class CloudTranslationProviderClientStub: CloudTranslationProviderClient {
    private let result: String
    var lastText: String?
    var lastAPIKey: String?

    init(result: String = "translated") {
        self.result = result
    }

    func translate(
        text: String,
        source: LanguageSource,
        target: Locale.Language,
        apiKey: String
    ) async throws -> String {
        lastText = text
        lastAPIKey = apiKey
        return result
    }
}
