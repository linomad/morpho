import XCTest
@testable import MorphoKit

final class TranslationEngineFactoryTests: XCTestCase {
    func testFactoryReturnsSiliconFlowEngineForProvider() {
        let engine = TranslationEngineStub()
        let factory = DefaultTranslationEngineFactory(
            siliconFlowEngine: engine
        )

        let resolved = factory.makeEngine(for: .siliconFlow)

        XCTAssertTrue(resolved is TranslationEngineStub)
    }
}

private final class TranslationEngineStub: TranslationEngine {
    func translate(
        _ text: String,
        source: LanguageSource,
        target: Locale.Language,
        apiKey: String?,
        modelID: String?
    ) async throws -> String {
        text
    }
}
