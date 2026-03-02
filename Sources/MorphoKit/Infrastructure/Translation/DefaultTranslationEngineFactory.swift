import Foundation

public final class DefaultTranslationEngineFactory: TranslationEngineFactoryProtocol {
    private let siliconFlowEngine: any TranslationEngine

    public init(
        siliconFlowEngine: any TranslationEngine
    ) {
        self.siliconFlowEngine = siliconFlowEngine
    }

    public func makeEngine(for provider: TranslationProvider) -> any TranslationEngine {
        switch provider {
        case .siliconFlow:
            return siliconFlowEngine
        }
    }
}
