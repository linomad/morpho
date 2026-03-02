import XCTest
@testable import MorphoKit

final class TranslationEngineFactoryTests: XCTestCase {
    func testFactoryReturnsSystemEngineForSystemBackend() {
        let factory = DefaultTranslationEngineFactory(
            systemEngine: SystemTranslationEngine(),
            cloudEngine: CloudTranslationEnginePlaceholder()
        )

        let engine = factory.makeEngine(for: .system)

        XCTAssertTrue(engine is SystemTranslationEngine)
    }

    func testFactoryReturnsCloudEngineForCloudBackend() {
        let factory = DefaultTranslationEngineFactory(
            systemEngine: SystemTranslationEngine(),
            cloudEngine: CloudTranslationEnginePlaceholder()
        )

        let engine = factory.makeEngine(for: .cloud)

        XCTAssertTrue(engine is CloudTranslationEnginePlaceholder)
    }
}
