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
            modelID: "deepseek-ai/DeepSeek-V3"
        )

        XCTAssertEqual(output, "你好")
        XCTAssertEqual(http.lastRequest?.url?.absoluteString, "https://api.siliconflow.cn/v1/chat/completions")
        XCTAssertEqual(http.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test")
        XCTAssertEqual(http.lastRequest?.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let requestBody = try XCTUnwrap(http.lastRequest?.httpBody)
        let bodyObject = try XCTUnwrap(JSONSerialization.jsonObject(with: requestBody) as? [String: Any])
        XCTAssertEqual(bodyObject["model"] as? String, "deepseek-ai/DeepSeek-V3")
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
                modelID: nil
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
