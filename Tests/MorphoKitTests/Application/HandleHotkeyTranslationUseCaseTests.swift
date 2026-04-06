import Foundation
import XCTest
@testable import MorphoKit

final class HandleHotkeyTranslationUseCaseTests: XCTestCase {
    func testExecuteFailsWhenAccessibilityPermissionMissing() async {
        let permission = PermissionStub(isTrusted: false)
        let contextProvider = ContextProviderStub()
        let replacer = TextReplacerSpy()
        let settingsStore = SettingsStoreStub()
        let engineFactory = EngineFactoryStub()
        let statusSink = StatusSinkSpy()

        let useCase = HandleHotkeyTranslationUseCase(
            permissionChecker: permission,
            contextProvider: contextProvider,
            textReplacer: replacer,
            settingsStore: settingsStore,
            engineFactory: engineFactory,
            statusSink: statusSink
        )

        let result = await useCase.execute()

        XCTAssertEqual(result, .failure(.accessibilityPermissionDenied))
        XCTAssertEqual(statusSink.last?.severity, .error)
        XCTAssertEqual(replacer.lastReplacementText, nil)
    }

    func testExecuteTranslatesSelectedTextWhenAvailable() async {
        let permission = PermissionStub(isTrusted: true)
        let context = TextContext(
            appBundleId: "com.apple.TextEdit",
            fullText: "hello world",
            selectedRange: NSRange(location: 0, length: 5),
            selectedText: "hello",
            isSecureField: false
        )

        let contextProvider = ContextProviderStub(context: context)
        let replacer = TextReplacerSpy()
        let settingsStore = SettingsStoreStub(
            settings: AppSettings.defaultValue.withTargetLanguage("zh-Hans")
        )
        let engine = TranslationEngineStub(translatedText: "你好")
        let engineFactory = EngineFactoryStub(engine: engine)
        let statusSink = StatusSinkSpy()

        let useCase = HandleHotkeyTranslationUseCase(
            permissionChecker: permission,
            contextProvider: contextProvider,
            textReplacer: replacer,
            settingsStore: settingsStore,
            engineFactory: engineFactory,
            statusSink: statusSink
        )

        let result = await useCase.execute()

        XCTAssertEqual(result, .success)
        XCTAssertEqual(engine.lastSourceText, "hello")
        XCTAssertEqual(engine.lastAPIKey, AppSettings.defaultValue.translationAPIKey)
        XCTAssertEqual(engine.lastModelID, AppSettings.defaultValue.translationModelID)
        XCTAssertEqual(engineFactory.lastProvider, .siliconFlow)
        XCTAssertEqual(replacer.lastReplacementText, "你好")
        XCTAssertEqual(replacer.lastReplacementMode, .selection)
        XCTAssertEqual(statusSink.last?.severity, .success)
    }

    func testExecuteFallsBackToFullTextWhenSelectionMissing() async {
        let permission = PermissionStub(isTrusted: true)
        let context = TextContext(
            appBundleId: "com.apple.TextEdit",
            fullText: "hello world",
            selectedRange: nil,
            selectedText: nil,
            isSecureField: false
        )

        let contextProvider = ContextProviderStub(context: context)
        let replacer = TextReplacerSpy()
        let settingsStore = SettingsStoreStub()
        let engine = TranslationEngineStub(translatedText: "hola mundo")
        let engineFactory = EngineFactoryStub(engine: engine)
        let statusSink = StatusSinkSpy()

        let useCase = HandleHotkeyTranslationUseCase(
            permissionChecker: permission,
            contextProvider: contextProvider,
            textReplacer: replacer,
            settingsStore: settingsStore,
            engineFactory: engineFactory,
            statusSink: statusSink
        )

        let result = await useCase.execute()

        XCTAssertEqual(result, .success)
        XCTAssertEqual(engine.lastSourceText, "hello world")
        XCTAssertEqual(replacer.lastReplacementMode, .entireField)
    }

    func testExecuteRoutesToPairTargetWhenAutoSourceDetectsFirstLanguage() async {
        let permission = PermissionStub(isTrusted: true)
        let context = TextContext(
            appBundleId: "com.apple.TextEdit",
            fullText: "你好",
            selectedRange: NSRange(location: 0, length: 2),
            selectedText: "你好",
            isSecureField: false
        )

        let contextProvider = ContextProviderStub(context: context)
        let replacer = TextReplacerSpy()
        var settings = AppSettings.defaultValue
        settings.sourceLanguage = .auto
        settings.targetLanguage = Locale.Language(identifier: "en")
        settings.autoSwitchLanguagePair = AutoSwitchLanguagePair(
            firstLanguage: Locale.Language(identifier: "zh-Hans"),
            secondLanguage: Locale.Language(identifier: "en")
        )
        let settingsStore = SettingsStoreStub(settings: settings)
        let engine = TranslationEngineStub(translatedText: "hello")
        let engineFactory = EngineFactoryStub(engine: engine)
        let statusSink = StatusSinkSpy()
        let languageDetector = SourceLanguageDetectorStub(
            detectedLanguage: Locale.Language(identifier: "zh-Hans")
        )

        let useCase = HandleHotkeyTranslationUseCase(
            permissionChecker: permission,
            contextProvider: contextProvider,
            textReplacer: replacer,
            settingsStore: settingsStore,
            engineFactory: engineFactory,
            statusSink: statusSink,
            sourceLanguageDetector: languageDetector
        )

        let result = await useCase.execute()

        XCTAssertEqual(result, .success)
        XCTAssertEqual(engine.lastTargetLanguage?.minimalIdentifier, "en")
        guard case .fixed(let sourceLanguage) = engine.lastSourceLanguage else {
            return XCTFail("Expected fixed source language.")
        }
        XCTAssertEqual(sourceLanguage.minimalIdentifier, "zh")
    }

    func testExecuteRoutesToPairTargetWhenAutoSourceDetectsSecondLanguage() async {
        let permission = PermissionStub(isTrusted: true)
        let context = TextContext(
            appBundleId: "com.apple.TextEdit",
            fullText: "hello",
            selectedRange: NSRange(location: 0, length: 5),
            selectedText: "hello",
            isSecureField: false
        )

        let contextProvider = ContextProviderStub(context: context)
        let replacer = TextReplacerSpy()
        var settings = AppSettings.defaultValue
        settings.sourceLanguage = .auto
        settings.targetLanguage = Locale.Language(identifier: "zh-Hans")
        settings.autoSwitchLanguagePair = AutoSwitchLanguagePair(
            firstLanguage: Locale.Language(identifier: "zh-Hans"),
            secondLanguage: Locale.Language(identifier: "en")
        )
        let settingsStore = SettingsStoreStub(settings: settings)
        let engine = TranslationEngineStub(translatedText: "你好")
        let engineFactory = EngineFactoryStub(engine: engine)
        let statusSink = StatusSinkSpy()
        let languageDetector = SourceLanguageDetectorStub(
            detectedLanguage: Locale.Language(identifier: "en")
        )

        let useCase = HandleHotkeyTranslationUseCase(
            permissionChecker: permission,
            contextProvider: contextProvider,
            textReplacer: replacer,
            settingsStore: settingsStore,
            engineFactory: engineFactory,
            statusSink: statusSink,
            sourceLanguageDetector: languageDetector
        )

        let result = await useCase.execute()

        XCTAssertEqual(result, .success)
        XCTAssertEqual(engine.lastTargetLanguage?.minimalIdentifier, "zh")
        guard case .fixed(let sourceLanguage) = engine.lastSourceLanguage else {
            return XCTFail("Expected fixed source language.")
        }
        XCTAssertEqual(sourceLanguage.minimalIdentifier, "en")
    }

    func testExecuteFailsForSecureField() async {
        let permission = PermissionStub(isTrusted: true)
        let context = TextContext(
            appBundleId: "com.apple.TextEdit",
            fullText: "secret",
            selectedRange: NSRange(location: 0, length: 6),
            selectedText: "secret",
            isSecureField: true
        )
        let contextProvider = ContextProviderStub(context: context)
        let replacer = TextReplacerSpy()
        let settingsStore = SettingsStoreStub()
        let engineFactory = EngineFactoryStub()
        let statusSink = StatusSinkSpy()

        let useCase = HandleHotkeyTranslationUseCase(
            permissionChecker: permission,
            contextProvider: contextProvider,
            textReplacer: replacer,
            settingsStore: settingsStore,
            engineFactory: engineFactory,
            statusSink: statusSink
        )

        let result = await useCase.execute()

        XCTAssertEqual(result, .failure(.secureInputUnsupported))
        XCTAssertEqual(replacer.lastReplacementText, nil)
        XCTAssertEqual(statusSink.last?.severity, .error)
    }

    func testExecuteFailsWhenNoTextAvailable() async {
        let permission = PermissionStub(isTrusted: true)
        let context = TextContext(
            appBundleId: "com.apple.TextEdit",
            fullText: "  ",
            selectedRange: nil,
            selectedText: nil,
            isSecureField: false
        )
        let contextProvider = ContextProviderStub(context: context)
        let replacer = TextReplacerSpy()
        let settingsStore = SettingsStoreStub()
        let engineFactory = EngineFactoryStub()
        let statusSink = StatusSinkSpy()

        let useCase = HandleHotkeyTranslationUseCase(
            permissionChecker: permission,
            contextProvider: contextProvider,
            textReplacer: replacer,
            settingsStore: settingsStore,
            engineFactory: engineFactory,
            statusSink: statusSink
        )

        let result = await useCase.execute()

        XCTAssertEqual(result, .failure(.noTextToTranslate))
        XCTAssertEqual(replacer.lastReplacementText, nil)
        XCTAssertEqual(statusSink.last?.severity, .warning)
    }

    func testExecuteReportsWarningWhenSelectionIsRequiredForCurrentControl() async {
        let permission = PermissionStub(isTrusted: true)
        let contextProvider = ContextProviderStub(error: .selectionRequiredForCurrentControl)
        let replacer = TextReplacerSpy()
        let settingsStore = SettingsStoreStub()
        let engineFactory = EngineFactoryStub()
        let statusSink = StatusSinkSpy()

        let useCase = HandleHotkeyTranslationUseCase(
            permissionChecker: permission,
            contextProvider: contextProvider,
            textReplacer: replacer,
            settingsStore: settingsStore,
            engineFactory: engineFactory,
            statusSink: statusSink
        )

        let result = await useCase.execute()

        XCTAssertEqual(result, .failure(.selectionRequiredForCurrentControl))
        XCTAssertEqual(statusSink.last?.severity, .warning)
        XCTAssertEqual(replacer.lastReplacementText, nil)
    }

    func testExecuteReportsWarningWhenReplacementRequiresSelection() async {
        let permission = PermissionStub(isTrusted: true)
        let context = TextContext(
            appBundleId: "com.apple.TextEdit",
            fullText: "hello world",
            selectedRange: NSRange(location: 0, length: 5),
            selectedText: "hello",
            isSecureField: false
        )
        let contextProvider = ContextProviderStub(context: context)
        let replacer = TextReplacerSpy(replaceError: TranslationWorkflowError.selectionRequiredForCurrentControl)
        let settingsStore = SettingsStoreStub()
        let engine = TranslationEngineStub(translatedText: "hola")
        let engineFactory = EngineFactoryStub(engine: engine)
        let statusSink = StatusSinkSpy()

        let useCase = HandleHotkeyTranslationUseCase(
            permissionChecker: permission,
            contextProvider: contextProvider,
            textReplacer: replacer,
            settingsStore: settingsStore,
            engineFactory: engineFactory,
            statusSink: statusSink
        )

        let result = await useCase.execute()

        XCTAssertEqual(result, .failure(.selectionRequiredForCurrentControl))
        XCTAssertEqual(statusSink.last?.severity, .warning)
    }

    func testExecuteAppendsRunHistoryWhenTranslationSucceeds() async {
        let permission = PermissionStub(isTrusted: true)
        let context = TextContext(
            appBundleId: "com.apple.TextEdit",
            fullText: "hello",
            selectedRange: NSRange(location: 0, length: 5),
            selectedText: "hello",
            isSecureField: false
        )
        let contextProvider = ContextProviderStub(context: context)
        let replacer = TextReplacerSpy()
        var settings = AppSettings.defaultValue
        settings.sourceLanguage = .fixed(Locale.Language(identifier: "en"))
        settings.targetLanguage = Locale.Language(identifier: "zh-Hans")
        settings.translationProvider = .siliconFlow
        settings.translationModelID = "deepseek-ai/DeepSeek-V3"
        let settingsStore = SettingsStoreStub(settings: settings)
        let engine = TranslationEngineStub(translatedText: "你好")
        let engineFactory = EngineFactoryStub(engine: engine)
        let statusSink = StatusSinkSpy()
        let runHistoryStore = RunHistoryStoreSpy()

        let useCase = HandleHotkeyTranslationUseCase(
            permissionChecker: permission,
            contextProvider: contextProvider,
            textReplacer: replacer,
            settingsStore: settingsStore,
            engineFactory: engineFactory,
            statusSink: statusSink,
            runHistoryStore: runHistoryStore
        )

        let result = await useCase.execute()

        XCTAssertEqual(result, .success)
        XCTAssertEqual(runHistoryStore.entries.count, 1)
        XCTAssertEqual(runHistoryStore.entries.first?.inputText, "hello")
        XCTAssertEqual(runHistoryStore.entries.first?.outputText, "你好")
        XCTAssertEqual(runHistoryStore.entries.first?.translationProvider, .siliconFlow)
        XCTAssertEqual(runHistoryStore.entries.first?.translationModelID, "deepseek-ai/DeepSeek-V3")
        XCTAssertEqual(runHistoryStore.entries.first?.workMode, .translate)
    }

    func testExecutePolishModeUsesDetectedLanguageForSourceAndTarget() async {
        let permission = PermissionStub(isTrusted: true)
        let context = TextContext(
            appBundleId: "com.apple.TextEdit",
            fullText: "I has a book.",
            selectedRange: NSRange(location: 0, length: 13),
            selectedText: "I has a book.",
            isSecureField: false
        )
        let contextProvider = ContextProviderStub(context: context)
        let replacer = TextReplacerSpy()
        var settings = AppSettings.defaultValue
        settings.workMode = .polish
        settings.targetLanguage = Locale.Language(identifier: "zh-Hans")
        let settingsStore = SettingsStoreStub(settings: settings)
        let engine = TranslationEngineStub(translatedText: "I have a book.")
        let engineFactory = EngineFactoryStub(engine: engine)
        let statusSink = StatusSinkSpy()
        let detector = SourceLanguageDetectorStub(detectedLanguage: Locale.Language(identifier: "en"))
        let runHistoryStore = RunHistoryStoreSpy()

        let useCase = HandleHotkeyTranslationUseCase(
            permissionChecker: permission,
            contextProvider: contextProvider,
            textReplacer: replacer,
            settingsStore: settingsStore,
            engineFactory: engineFactory,
            statusSink: statusSink,
            sourceLanguageDetector: detector,
            runHistoryStore: runHistoryStore
        )

        let result = await useCase.execute()

        XCTAssertEqual(result, .success)
        guard case .fixed(let sourceLanguage) = engine.lastSourceLanguage else {
            return XCTFail("Expected fixed source language in polish mode.")
        }
        XCTAssertEqual(sourceLanguage.minimalIdentifier, "en")
        XCTAssertEqual(engine.lastTargetLanguage?.minimalIdentifier, "en")
        XCTAssertEqual(engine.lastWorkMode, .polish)
        XCTAssertEqual(replacer.lastReplacementText, "I have a book.")
        XCTAssertEqual(statusSink.last?.message.hasPrefix("润色完成"), true)
        XCTAssertEqual(runHistoryStore.entries.first?.workMode, .polish)
    }
}

private final class PermissionStub: AccessibilityPermissionChecking {
    private let trusted: Bool

    init(isTrusted: Bool) {
        self.trusted = isTrusted
    }

    func isTrusted(prompt: Bool) -> Bool {
        trusted
    }
}

private final class ContextProviderStub: TextContextProvider {
    private let context: TextContext?
    private let error: TranslationWorkflowError?

    init(context: TextContext? = nil, error: TranslationWorkflowError? = nil) {
        self.context = context
        self.error = error
    }

    func captureFocusedContext() throws -> TextContext {
        if let error {
            throw error
        }

        if let context {
            return context
        }

        throw TranslationWorkflowError.focusedInputUnavailable
    }
}

private final class TextReplacerSpy: TextReplacer {
    private let replaceError: Error?
    var lastReplacementMode: ReplacementMode?
    var lastReplacementText: String?

    init(replaceError: Error? = nil) {
        self.replaceError = replaceError
    }

    func replace(in context: TextContext, with translatedText: String, mode: ReplacementMode) throws {
        if let replaceError {
            throw replaceError
        }

        lastReplacementMode = mode
        lastReplacementText = translatedText
    }
}

private final class SettingsStoreStub: SettingsStore {
    var settings: AppSettings

    init(settings: AppSettings = .defaultValue) {
        self.settings = settings
    }

    func load() -> AppSettings {
        settings
    }

    func save(_ settings: AppSettings) {
        self.settings = settings
    }
}

private final class TranslationEngineStub: TranslationEngine {
    private let translatedText: String
    var lastSourceText: String?
    var lastAPIKey: String?
    var lastSourceLanguage: LanguageSource?
    var lastTargetLanguage: Locale.Language?
    var lastModelID: String?
    var lastWorkMode: WorkMode?

    init(translatedText: String = "translated") {
        self.translatedText = translatedText
    }

    func translate(
        _ text: String,
        source: LanguageSource,
        target: Locale.Language,
        apiKey: String?,
        modelID: String?,
        workMode: WorkMode
    ) async throws -> String {
        lastSourceText = text
        lastSourceLanguage = source
        lastTargetLanguage = target
        lastAPIKey = apiKey
        lastModelID = modelID
        lastWorkMode = workMode
        return translatedText
    }
}

private final class SourceLanguageDetectorStub: SourceLanguageDetecting {
    private let detectedLanguage: Locale.Language?

    init(detectedLanguage: Locale.Language?) {
        self.detectedLanguage = detectedLanguage
    }

    func detectLanguage(for text: String) -> Locale.Language? {
        detectedLanguage
    }
}

private final class EngineFactoryStub: TranslationEngineFactoryProtocol {
    private let injectedEngine: (any TranslationEngine)?
    private(set) var lastProvider: TranslationProvider?

    init(engine: (any TranslationEngine)? = nil) {
        self.injectedEngine = engine
    }

    func makeEngine(for provider: TranslationProvider) -> any TranslationEngine {
        lastProvider = provider
        if let injectedEngine {
            return injectedEngine
        }

        return TranslationEngineStub()
    }
}

private final class StatusSinkSpy: StatusReporting {
    var entries: [StatusEntry] = []

    var last: StatusEntry? {
        entries.last
    }

    func publish(_ entry: StatusEntry) {
        entries.append(entry)
    }
}

private final class RunHistoryStoreSpy: RunHistoryStore, @unchecked Sendable {
    private(set) var entries: [RunHistoryEntry] = []

    func load(limit: Int) -> [RunHistoryEntry] {
        Array(entries.prefix(limit))
    }

    func append(_ entry: RunHistoryEntry) {
        entries.insert(entry, at: 0)
    }

    func clear() {
        entries = []
    }
}
