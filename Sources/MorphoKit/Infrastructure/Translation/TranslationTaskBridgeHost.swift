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
        source: Locale.Language?,
        target: Locale.Language
    ) async throws -> String {
        createWindowIfNeeded()

        do {
            return try await coordinator.submit(text: text, source: source, target: target)
        } catch let error as TranslationWorkflowError {
            throw error
        } catch let error as TranslationError {
            throw TranslationErrorMapper.map(error)
        } catch is CancellationError {
            throw TranslationWorkflowError.translationInterrupted
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
final class TranslationTaskCoordinator: ObservableObject {
    @Published var configuration: TranslationSession.Configuration?

    private var pendingRequest: PendingRequest?
    private var isBridgeReady = false
    private let bridgeReadyTimeoutNanoseconds: UInt64
    private let requestStartTimeoutNanoseconds: UInt64

    init(
        bridgeReadyTimeoutNanoseconds: UInt64 = 3_000_000_000,
        requestStartTimeoutNanoseconds: UInt64 = 3_000_000_000
    ) {
        self.bridgeReadyTimeoutNanoseconds = bridgeReadyTimeoutNanoseconds
        self.requestStartTimeoutNanoseconds = requestStartTimeoutNanoseconds
    }

    func markBridgeReady() {
        isBridgeReady = true
    }

    func markBridgeUnavailable() {
        isBridgeReady = false
    }

    func submit(
        text: String,
        source: Locale.Language?,
        target: Locale.Language
    ) async throws -> String {
        try await waitForBridgeReady()

        guard pendingRequest == nil else {
            throw TranslationWorkflowError.translationInProgress
        }

        let requestID = UUID()
        let timeoutNanoseconds = requestStartTimeoutNanoseconds

        return try await withCheckedThrowingContinuation { continuation in
            let timeoutTask = Task { [weak self, requestID, timeoutNanoseconds] in
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                self?.failPendingRequestIfNeeded(
                    id: requestID,
                    error: TranslationWorkflowError.translationSessionStartupTimeout,
                    onlyIfNotStarted: true
                )
            }

            pendingRequest = PendingRequest(
                id: requestID,
                text: text,
                continuation: continuation,
                hasStartedProcessing: false,
                timeoutTask: timeoutTask
            )
            configuration = TranslationSession.Configuration(source: source, target: target)
        }
    }

    func process(session: TranslationSession) async {
        guard let pendingRequest else {
            return
        }

        pendingRequest.hasStartedProcessing = true
        pendingRequest.timeoutTask.cancel()

        defer {
            self.pendingRequest = nil
            cleanupConfiguration()
        }

        do {
            try await session.prepareTranslation()
            let response = try await session.translate(pendingRequest.text)
            pendingRequest.continuation.resume(returning: response.targetText)
        } catch let error as TranslationError {
            pendingRequest.continuation.resume(throwing: TranslationErrorMapper.map(error))
        } catch is CancellationError {
            pendingRequest.continuation.resume(throwing: TranslationWorkflowError.translationInterrupted)
        } catch {
            pendingRequest.continuation.resume(throwing: error)
        }
    }

    private func waitForBridgeReady() async throws {
        guard !isBridgeReady else {
            return
        }

        let startedAt = DispatchTime.now().uptimeNanoseconds
        while !isBridgeReady {
            let elapsed = DispatchTime.now().uptimeNanoseconds - startedAt
            if elapsed >= bridgeReadyTimeoutNanoseconds {
                throw TranslationWorkflowError.translationSessionStartupTimeout
            }

            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private func failPendingRequestIfNeeded(
        id: UUID,
        error: TranslationWorkflowError,
        onlyIfNotStarted: Bool
    ) {
        guard let pendingRequest, pendingRequest.id == id else {
            return
        }

        if onlyIfNotStarted, pendingRequest.hasStartedProcessing {
            return
        }

        self.pendingRequest = nil
        pendingRequest.timeoutTask.cancel()
        cleanupConfiguration()
        pendingRequest.continuation.resume(throwing: error)
    }

    private func cleanupConfiguration() {
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
            .onAppear {
                coordinator.markBridgeReady()
            }
            .onDisappear {
                coordinator.markBridgeUnavailable()
            }
    }
}

private final class PendingRequest {
    let id: UUID
    let text: String
    let continuation: CheckedContinuation<String, Error>
    var hasStartedProcessing: Bool
    let timeoutTask: Task<Void, Never>

    init(
        id: UUID,
        text: String,
        continuation: CheckedContinuation<String, Error>,
        hasStartedProcessing: Bool,
        timeoutTask: Task<Void, Never>
    ) {
        self.id = id
        self.text = text
        self.continuation = continuation
        self.hasStartedProcessing = hasStartedProcessing
        self.timeoutTask = timeoutTask
    }
}
