import Foundation
import XCTest
@testable import MorphoKit

final class CloudTranslationEngineTests: XCTestCase {
    func testTranslateReturnsTrimmedInputWhenFixedSourceMatchesTargetInTranslateMode() async throws {
        let client = CloudTranslationProviderClientStub(result: "should-not-be-used")
        let engine = CloudTranslationEngine(
            client: client
        )

        let output = try await engine.translate(
            " hello ",
            source: .fixed(Locale.Language(identifier: "en")),
            target: Locale.Language(identifier: "en"),
            apiKey: "sk-test",
            modelID: nil,
            workMode: .translate
        )

        XCTAssertEqual(output, "hello")
        XCTAssertEqual(client.callCount, 0)
    }

    func testTranslatePolishModeBypassesSameLanguageShortcut() async throws {
        let client = CloudTranslationProviderClientStub(result: "I have a book.")
        let engine = CloudTranslationEngine(
            client: client
        )

        let output = try await engine.translate(
            "I has a book.",
            source: .fixed(Locale.Language(identifier: "en")),
            target: Locale.Language(identifier: "en"),
            apiKey: "sk-test",
            modelID: nil,
            workMode: .polish
        )

        XCTAssertEqual(output, "I have a book.")
        XCTAssertEqual(client.callCount, 1)
        XCTAssertEqual(client.lastWorkMode, .polish)
    }

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
                apiKey: "",
                modelID: nil
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
            apiKey: "sk-test",
            modelID: "deepseek-ai/DeepSeek-V3"
        )

        XCTAssertEqual(output, "你好")
        XCTAssertEqual(client.lastAPIKey, "sk-test")
        XCTAssertEqual(client.lastText, "hello")
        XCTAssertEqual(client.lastModelID, "deepseek-ai/DeepSeek-V3")
    }
}

private final class CloudTranslationProviderClientStub: CloudTranslationProviderClient {
    private let result: String
    var callCount: Int = 0
    var lastText: String?
    var lastAPIKey: String?
    var lastModelID: String?
    var lastWorkMode: WorkMode?

    init(result: String = "translated") {
        self.result = result
    }

    func translate(
        text: String,
        source: LanguageSource,
        target: Locale.Language,
        apiKey: String,
        modelID: String?,
        workMode: WorkMode
    ) async throws -> String {
        callCount += 1
        lastText = text
        lastAPIKey = apiKey
        lastModelID = modelID
        lastWorkMode = workMode
        return result
    }
}
