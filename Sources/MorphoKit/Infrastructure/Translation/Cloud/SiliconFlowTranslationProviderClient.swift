import Foundation

public final class SiliconFlowTranslationProviderClient: CloudTranslationProviderClient {
    private let httpClient: any CloudHTTPClient
    private let endpoint: URL
    private let model: String

    public init(
        httpClient: any CloudHTTPClient = URLSessionCloudHTTPClient(),
        endpoint: URL = URL(string: "https://api.siliconflow.cn/v1/chat/completions")!,
        model: String = "deepseek-ai/DeepSeek-V3"
    ) {
        self.httpClient = httpClient
        self.endpoint = endpoint
        self.model = model
    }

    public func translate(
        text: String,
        source: LanguageSource,
        target: Locale.Language,
        apiKey: String
    ) async throws -> String {
        let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedText.isEmpty else {
            throw TranslationWorkflowError.noTextToTranslate
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body = SiliconFlowChatCompletionsRequest(
            model: model,
            messages: [
                .init(
                    role: "system",
                    content: "You are a translation engine. Return only translated text without explanations."
                ),
                .init(
                    role: "user",
                    content: buildUserPrompt(text: normalizedText, source: source, target: target)
                )
            ],
            temperature: 0
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await httpClient.send(request)

        switch response.statusCode {
        case 200 ... 299:
            break
        case 401, 403:
            throw TranslationWorkflowError.cloudAuthenticationFailed
        case 429:
            throw TranslationWorkflowError.cloudRateLimited
        case 500 ... 599:
            throw TranslationWorkflowError.cloudServiceUnavailable
        default:
            throw TranslationWorkflowError.translationFailed
        }

        do {
            let decoded = try JSONDecoder().decode(SiliconFlowChatCompletionsResponse.self, from: data)
            guard let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
                  !content.isEmpty else {
                throw TranslationWorkflowError.translationFailed
            }
            return content
        } catch let error as TranslationWorkflowError {
            throw error
        } catch {
            throw TranslationWorkflowError.translationFailed
        }
    }

    private func buildUserPrompt(text: String, source: LanguageSource, target: Locale.Language) -> String {
        let sourceDescription: String
        switch source {
        case .auto:
            sourceDescription = "auto"
        case .fixed(let language):
            sourceDescription = LanguageIdentifierCodec.persistedIdentifier(for: language)
        }

        return """
        Translate the text below.
        Source language: \(sourceDescription)
        Target language: \(LanguageIdentifierCodec.persistedIdentifier(for: target))
        Text:
        \(text)
        """
    }
}

private struct SiliconFlowChatCompletionsRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
    let temperature: Int
}

private struct SiliconFlowChatCompletionsResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
}
