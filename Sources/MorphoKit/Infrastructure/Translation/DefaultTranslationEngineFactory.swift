import Foundation

public final class DefaultTranslationEngineFactory: TranslationEngineFactoryProtocol {
    private let systemEngine: any TranslationEngine
    private let cloudEngine: any TranslationEngine

    public init(
        systemEngine: any TranslationEngine,
        cloudEngine: any TranslationEngine
    ) {
        self.systemEngine = systemEngine
        self.cloudEngine = cloudEngine
    }

    public func makeEngine(for backend: TranslationBackend) -> any TranslationEngine {
        switch backend {
        case .system:
            return systemEngine
        case .cloud:
            return cloudEngine
        }
    }
}
