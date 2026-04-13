import Foundation
import OSLog

public final class LayeredTextContextGateway: TextContextProvider, TextReplacer {
    private enum RouteChannel {
        case primary
        case fallback
    }

    private struct RouteEntry {
        let channel: RouteChannel
        let context: TextContext
    }

    private let primaryGateway: any TextContextProvider & TextReplacer
    private let fallbackGateway: any TextContextProvider & TextReplacer
    private var routeEntries: [UUID: RouteEntry] = [:]
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "MorphoKit",
        category: "LayeredTextContextGateway"
    )

    public init() {
        self.primaryGateway = AXTextContextGateway()
        self.fallbackGateway = ControlledPasteTextGateway()
    }

    init(
        primaryGateway: any TextContextProvider & TextReplacer,
        fallbackGateway: any TextContextProvider & TextReplacer
    ) {
        self.primaryGateway = primaryGateway
        self.fallbackGateway = fallbackGateway
    }

    public func captureFocusedContext() throws -> TextContext {
        do {
            let context = try primaryGateway.captureFocusedContext()
            Self.logger.debug("capture succeeded via primary; appBundleId=\(context.appBundleId, privacy: .public)")
            return wrap(context, channel: .primary)
        } catch let error as TranslationWorkflowError {
            Self.logger.notice(
                "primary capture failed; error=\(String(describing: error), privacy: .public); fallback=\(self.shouldFallback(for: error), privacy: .public)"
            )
            guard shouldFallback(for: error) else {
                throw error
            }
        }

        do {
            let fallbackContext = try fallbackGateway.captureFocusedContext()
            Self.logger.debug("capture succeeded via fallback; appBundleId=\(fallbackContext.appBundleId, privacy: .public)")
            return wrap(fallbackContext, channel: .fallback)
        } catch let error as TranslationWorkflowError {
            Self.logger.error("fallback capture failed; error=\(String(describing: error), privacy: .public)")
            throw error
        }
    }

    public func replace(in context: TextContext, with translatedText: String, mode: ReplacementMode) throws {
        guard let token = context.replacementToken, let routeEntry = routeEntries[token] else {
            throw TranslationWorkflowError.replacementFailed
        }
        defer {
            routeEntries[token] = nil
        }

        switch routeEntry.channel {
        case .primary:
            try primaryGateway.replace(in: routeEntry.context, with: translatedText, mode: mode)
        case .fallback:
            try fallbackGateway.replace(in: routeEntry.context, with: translatedText, mode: mode)
        }
    }

    private func wrap(_ context: TextContext, channel: RouteChannel) -> TextContext {
        guard !context.isSecureField else {
            return context
        }

        let token = UUID()
        routeEntries[token] = RouteEntry(channel: channel, context: context)

        return TextContext(
            appBundleId: context.appBundleId,
            fullText: context.fullText,
            selectedRange: context.selectedRange,
            selectedText: context.selectedText,
            isSecureField: context.isSecureField,
            replacementToken: token
        )
    }

    private func shouldFallback(for error: TranslationWorkflowError) -> Bool {
        switch error {
        case .focusedInputUnavailable, .unsupportedInputControl:
            return true
        default:
            return false
        }
    }
}
