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

    init(context: TextContext? = nil) {
        self.context = context
    }

    func captureFocusedContext() throws -> TextContext {
        if let context {
            return context
        }

        throw TranslationWorkflowError.focusedInputUnavailable
    }
}

private final class TextReplacerSpy: TextReplacer {
    var lastReplacementMode: ReplacementMode?
    var lastReplacementText: String?

    func replace(in context: TextContext, with translatedText: String, mode: ReplacementMode) throws {
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

    init(translatedText: String = "translated") {
        self.translatedText = translatedText
    }

    func translate(_ text: String, source: LanguageSource, target: Locale.Language) async throws -> String {
        lastSourceText = text
        return translatedText
    }
}

private final class EngineFactoryStub: TranslationEngineFactoryProtocol {
    private let injectedEngine: (any TranslationEngine)?

    init(engine: (any TranslationEngine)? = nil) {
        self.injectedEngine = engine
    }

    func makeEngine(for backend: TranslationBackend) -> any TranslationEngine {
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
