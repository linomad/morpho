import Foundation

public final class HandleHotkeyTranslationUseCase: @unchecked Sendable {
    private let permissionChecker: AccessibilityPermissionChecking
    private let contextProvider: TextContextProvider
    private let textReplacer: TextReplacer
    private let settingsStore: SettingsStore
    private let engineFactory: TranslationEngineFactoryProtocol
    private let statusSink: StatusReporting

    public init(
        permissionChecker: AccessibilityPermissionChecking,
        contextProvider: TextContextProvider,
        textReplacer: TextReplacer,
        settingsStore: SettingsStore,
        engineFactory: TranslationEngineFactoryProtocol,
        statusSink: StatusReporting
    ) {
        self.permissionChecker = permissionChecker
        self.contextProvider = contextProvider
        self.textReplacer = textReplacer
        self.settingsStore = settingsStore
        self.engineFactory = engineFactory
        self.statusSink = statusSink
    }

    public func execute() async -> TranslationExecutionResult {
        guard permissionChecker.isTrusted(prompt: true) else {
            return fail(.accessibilityPermissionDenied, severity: .error)
        }

        let context: TextContext
        do {
            context = try contextProvider.captureFocusedContext()
        } catch let error as TranslationWorkflowError {
            return fail(error, severity: severity(for: error))
        } catch {
            return fail(.focusedInputUnavailable, severity: .error)
        }

        guard !context.isSecureField else {
            return fail(.secureInputUnsupported, severity: .error)
        }

        guard let payload = selectionPayload(from: context) else {
            return fail(.noTextToTranslate, severity: .warning)
        }

        let settings = settingsStore.load()
        let engine = engineFactory.makeEngine(for: settings.translationProvider)

        let translatedText: String
        do {
            translatedText = try await engine.translate(
                payload.text,
                source: settings.sourceLanguage,
                target: settings.targetLanguage,
                apiKey: settings.translationAPIKey
            )
        } catch let error as TranslationWorkflowError {
            return fail(error, severity: severity(for: error))
        } catch {
            return fail(.translationFailed, severity: .error)
        }

        do {
            try textReplacer.replace(in: context, with: translatedText, mode: payload.mode)
        } catch let error as TranslationWorkflowError {
            return fail(error, severity: severity(for: error))
        } catch {
            return fail(.replacementFailed, severity: .error)
        }

        statusSink.publish(
            StatusEntry(
                message: "翻译完成",
                severity: .success
            )
        )

        return .success
    }

    private func selectionPayload(from context: TextContext) -> (text: String, mode: ReplacementMode)? {
        if let selectedText = context.selectedText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !selectedText.isEmpty {
            return (selectedText, .selection)
        }

        let fullText = context.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fullText.isEmpty else {
            return nil
        }

        return (fullText, .entireField)
    }

    @discardableResult
    private func fail(
        _ error: TranslationWorkflowError,
        severity: StatusSeverity
    ) -> TranslationExecutionResult {
        statusSink.publish(
            StatusEntry(
                message: TranslationErrorPresenter.message(for: error),
                severity: severity
            )
        )

        return .failure(error)
    }

    private func severity(for error: TranslationWorkflowError) -> StatusSeverity {
        switch error {
        case .selectionRequiredForCurrentControl:
            return .warning
        default:
            return .error
        }
    }
}
