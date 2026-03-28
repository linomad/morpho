import Foundation

public final class HandleHotkeyTranslationUseCase: @unchecked Sendable {
    private let permissionChecker: AccessibilityPermissionChecking
    private let contextProvider: TextContextProvider
    private let textReplacer: TextReplacer
    private let settingsStore: SettingsStore
    private let engineFactory: TranslationEngineFactoryProtocol
    private let statusSink: StatusReporting
    private let sourceLanguageDetector: any SourceLanguageDetecting
    private let runHistoryStore: RunHistoryStore

    public init(
        permissionChecker: AccessibilityPermissionChecking,
        contextProvider: TextContextProvider,
        textReplacer: TextReplacer,
        settingsStore: SettingsStore,
        engineFactory: TranslationEngineFactoryProtocol,
        statusSink: StatusReporting,
        sourceLanguageDetector: any SourceLanguageDetecting = NoopSourceLanguageDetector(),
        runHistoryStore: RunHistoryStore = NoopRunHistoryStore()
    ) {
        self.permissionChecker = permissionChecker
        self.contextProvider = contextProvider
        self.textReplacer = textReplacer
        self.settingsStore = settingsStore
        self.engineFactory = engineFactory
        self.statusSink = statusSink
        self.sourceLanguageDetector = sourceLanguageDetector
        self.runHistoryStore = runHistoryStore
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
        let languageRoute = resolveLanguageRoute(for: payload.text, settings: settings)

        let translatedText: String
        do {
            translatedText = try await engine.translate(
                payload.text,
                source: languageRoute.source,
                target: languageRoute.target,
                apiKey: settings.translationAPIKey,
                modelID: settings.translationModelID
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

        appendRunHistory(
            inputText: payload.text,
            outputText: translatedText,
            route: languageRoute,
            settings: settings
        )

        let truncatedResult = translatedText.count > 50
            ? String(translatedText.prefix(50)) + "…"
            : translatedText

        statusSink.publish(
            StatusEntry(
                message: "翻译完成: \(truncatedResult)",
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

    private func resolveLanguageRoute(
        for text: String,
        settings: AppSettings
    ) -> (source: LanguageSource, target: Locale.Language) {
        guard
            case .auto = settings.sourceLanguage,
            let pair = settings.autoSwitchLanguagePair,
            let detectedLanguage = sourceLanguageDetector.detectLanguage(for: text)
        else {
            return (settings.sourceLanguage, settings.targetLanguage)
        }

        let detectedIdentifier = detectedLanguage.minimalIdentifier
        let firstIdentifier = pair.firstLanguage.minimalIdentifier
        let secondIdentifier = pair.secondLanguage.minimalIdentifier

        if detectedIdentifier == firstIdentifier {
            return (.fixed(pair.firstLanguage), pair.secondLanguage)
        }

        if detectedIdentifier == secondIdentifier {
            return (.fixed(pair.secondLanguage), pair.firstLanguage)
        }

        return (settings.sourceLanguage, settings.targetLanguage)
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

    private func appendRunHistory(
        inputText: String,
        outputText: String,
        route: (source: LanguageSource, target: Locale.Language),
        settings: AppSettings
    ) {
        let sourceIdentifier: String
        switch route.source {
        case .auto:
            sourceIdentifier = "auto"
        case .fixed(let language):
            sourceIdentifier = LanguageIdentifierCodec.persistedIdentifier(for: language)
        }

        let targetIdentifier = LanguageIdentifierCodec.persistedIdentifier(for: route.target)

        runHistoryStore.append(
            RunHistoryEntry(
                inputText: inputText,
                outputText: outputText,
                sourceLanguageIdentifier: sourceIdentifier,
                targetLanguageIdentifier: targetIdentifier,
                translationProvider: settings.translationProvider,
                translationModelID: settings.translationModelID
            )
        )
    }
}

public struct NoopSourceLanguageDetector: SourceLanguageDetecting {
    public init() {}

    public func detectLanguage(for text: String) -> Locale.Language? {
        nil
    }
}
