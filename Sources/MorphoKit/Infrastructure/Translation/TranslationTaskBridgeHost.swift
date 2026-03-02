import AppKit
import Foundation
import SwiftUI
@preconcurrency import Translation

@MainActor
final class TranslationTaskBridgeHost {
    static let shared = TranslationTaskBridgeHost()

    private let coordinator = TranslationTaskCoordinator()
    private var window: NSWindow?

    private init() {
        createWindowIfNeeded()
    }

    func translate(
        text: String,
        source: LanguageSource,
        target: Locale.Language
    ) async throws -> String {
        createWindowIfNeeded()

        do {
            return try await coordinator.submit(text: text, source: source, target: target)
        } catch let error as TranslationError {
            switch error {
            case .unsupportedSourceLanguage,
                 .unsupportedTargetLanguage,
                 .unsupportedLanguagePairing:
                throw TranslationWorkflowError.systemTranslatorUnavailable
            default:
                throw TranslationWorkflowError.translationFailed
            }
        } catch {
            throw TranslationWorkflowError.translationFailed
        }
    }

    private func createWindowIfNeeded() {
        guard window == nil else {
            return
        }

        let host = NSHostingView(rootView: TranslationTaskBridgeView(coordinator: coordinator))
        host.frame = NSRect(x: 0, y: 0, width: 1, height: 1)

        let window = NSWindow(
            contentRect: NSRect(x: -10_000, y: -10_000, width: 1, height: 1),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .normal
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = host
        window.orderFrontRegardless()

        self.window = window
    }
}

@MainActor
private final class TranslationTaskCoordinator: ObservableObject {
    @Published var configuration: TranslationSession.Configuration?

    private var pendingRequest: PendingRequest?

    func submit(
        text: String,
        source: LanguageSource,
        target: Locale.Language
    ) async throws -> String {
        guard pendingRequest == nil else {
            throw TranslationWorkflowError.translationFailed
        }

        let sourceLanguage: Locale.Language?
        switch source {
        case .auto:
            sourceLanguage = nil
        case .fixed(let fixed):
            sourceLanguage = fixed
        }

        return try await withCheckedThrowingContinuation { continuation in
            pendingRequest = PendingRequest(text: text, continuation: continuation)
            configuration = TranslationSession.Configuration(source: sourceLanguage, target: target)
        }
    }

    func process(session: TranslationSession) async {
        guard let pendingRequest else {
            return
        }

        self.pendingRequest = nil

        do {
            let response = try await session.translate(pendingRequest.text)
            pendingRequest.continuation.resume(returning: response.targetText)
        } catch {
            pendingRequest.continuation.resume(throwing: error)
        }

        configuration?.invalidate()
        configuration = nil
    }
}

private struct TranslationTaskBridgeView: View {
    @ObservedObject var coordinator: TranslationTaskCoordinator

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .translationTask(coordinator.configuration) { session in
                await coordinator.process(session: session)
            }
    }
}

private struct PendingRequest {
    let text: String
    let continuation: CheckedContinuation<String, Error>
}
