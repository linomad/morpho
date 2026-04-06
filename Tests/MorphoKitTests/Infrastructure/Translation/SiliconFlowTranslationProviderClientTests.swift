import Foundation
import XCTest
@testable import MorphoKit

final class SiliconFlowTranslationProviderClientTests: XCTestCase {
    func testTranslateBuildsRequestAndParsesResponse() async throws {
        let expectedResponse = """
        {
          "choices": [
            {
              "message": {
                "content": "你好"
              }
            }
          ]
        }
        """.data(using: .utf8) ?? Data()

        let http = CloudHTTPClientStub(
            responseData: expectedResponse,
            statusCode: 200
        )

        let client = SiliconFlowTranslationProviderClient(
            httpClient: http,
            model: "deepseek-ai/DeepSeek-V3"
        )

        let output = try await client.translate(
            text: "hello",
            source: .auto,
            target: Locale.Language(identifier: "zh-Hans"),
            apiKey: "sk-test",
            modelID: "deepseek-ai/DeepSeek-V3",
            workMode: .translate
        )

        XCTAssertEqual(output, "你好")
        XCTAssertEqual(http.lastRequest?.url?.absoluteString, "https://api.siliconflow.cn/v1/chat/completions")
        XCTAssertEqual(http.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test")
        XCTAssertEqual(http.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let requestBody = try XCTUnwrap(http.lastRequest?.httpBody)
        let bodyObject = try XCTUnwrap(JSONSerialization.jsonObject(with: requestBody) as? [String: Any])
        XCTAssertEqual(bodyObject["model"] as? String, "deepseek-ai/DeepSeek-V3")
    }

    func testTranslateInPolishModeBuildsProofreadingPrompt() async throws {
        let expectedResponse = """
        {
          "choices": [
            {
              "message": {
                "content": "I have a book."
              }
            }
          ]
        }
        """.data(using: .utf8) ?? Data()

        let http = CloudHTTPClientStub(
            responseData: expectedResponse,
            statusCode: 200
        )

        let client = SiliconFlowTranslationProviderClient(
            httpClient: http,
            model: "deepseek-ai/DeepSeek-V3"
        )

        _ = try await client.translate(
            text: "I has a book.",
            source: .fixed(Locale.Language(identifier: "en")),
            target: Locale.Language(identifier: "en"),
            apiKey: "sk-test",
            modelID: nil,
            workMode: .polish
        )

        let requestBody = try XCTUnwrap(http.lastRequest?.httpBody)
        let bodyObject = try XCTUnwrap(JSONSerialization.jsonObject(with: requestBody) as? [String: Any])
        let messages = try XCTUnwrap(bodyObject["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages.first?["role"] as? String, "system")
        XCTAssertEqual(
            messages.first?["content"] as? String,
            "You are a text proofreading engine. Return only the corrected text without explanations."
        )

        let userPrompt = try XCTUnwrap(messages.last?["content"] as? String)
        XCTAssertTrue(userPrompt.contains("Do NOT translate to another language."))
        XCTAssertTrue(userPrompt.contains("Source language: en"))
        XCTAssertTrue(userPrompt.contains("I has a book."))
    }

    func testTranslateMapsUnauthorizedToAuthenticationError() async {
        let http = CloudHTTPClientStub(responseData: Data(), statusCode: 401)
        let client = SiliconFlowTranslationProviderClient(httpClient: http)

        do {
            _ = try await client.translate(
                text: "hello",
                source: .auto,
                target: Locale.Language(identifier: "zh-Hans"),
                apiKey: "sk-test",
                modelID: nil,
                workMode: .translate
            )
            XCTFail("Expected error")
        } catch let error as TranslationWorkflowError {
            XCTAssertEqual(error, .cloudAuthenticationFailed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private final class CloudHTTPClientStub: CloudHTTPClient {
    private let responseData: Data
    private let statusCode: Int
    var lastRequest: URLRequest?

    init(responseData: Data, statusCode: Int) {
        self.responseData = responseData
        self.statusCode = statusCode
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lastRequest = request
        let url = request.url ?? URL(string: "https://example.com")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (responseData, response)
    }
}
