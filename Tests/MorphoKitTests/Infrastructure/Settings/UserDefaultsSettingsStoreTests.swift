import Foundation
import XCTest
@testable import MorphoKit

final class UserDefaultsSettingsStoreTests: XCTestCase {
    func testSavePersistsSourceAndTargetLanguageWithScriptInformation() throws {
        let defaults = makeIsolatedDefaults()
        let store = UserDefaultsSettingsStore(defaults: defaults)
        let settings = AppSettings(
            hotkey: .defaultValue,
            sourceLanguage: .fixed(Locale.Language(identifier: "zh-Hant")),
            targetLanguage: Locale.Language(identifier: "zh-Hans"),
            translationProvider: .siliconFlow,
            translationAPIKey: "sk-test-save"
        )

        store.save(settings)

        guard let data = defaults.data(forKey: "morpho.app.settings") else {
            XCTFail("Expected persisted settings data.")
            return
        }

        let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(raw["sourceLanguageIdentifier"] as? String, Locale.Language(identifier: "zh-Hant").maximalIdentifier)
        XCTAssertEqual(raw["targetLanguageIdentifier"] as? String, Locale.Language(identifier: "zh-Hans").maximalIdentifier)
        XCTAssertEqual(raw["translationAPIKey"] as? String, "sk-test-save")
    }

    func testLoadRestoresTraditionalChineseSourceLanguageSelection() {
        let defaults = makeIsolatedDefaults()
        let store = UserDefaultsSettingsStore(defaults: defaults)
        let settings = AppSettings(
            hotkey: .defaultValue,
            sourceLanguage: .fixed(Locale.Language(identifier: "zh-Hant")),
            targetLanguage: Locale.Language(identifier: "en"),
            translationProvider: .siliconFlow,
            translationAPIKey: "sk-test-load"
        )

        store.save(settings)
        let loaded = store.load()

        guard case .fixed(let loadedSourceLanguage) = loaded.sourceLanguage else {
            XCTFail("Expected fixed source language.")
            return
        }

        let displayIdentifier = LanguageIdentifierCodec.displayIdentifier(
            for: loadedSourceLanguage,
            supportedIdentifiers: ["en", "zh-Hans", "zh-Hant"]
        )
        XCTAssertEqual(displayIdentifier, "zh-Hant")
        XCTAssertEqual(loaded.translationAPIKey, "sk-test-load")
    }

    func testLoadMigratesLegacyBackendToSiliconFlowProvider() throws {
        let defaults = makeIsolatedDefaults()
        let store = UserDefaultsSettingsStore(defaults: defaults)

        let legacyPayload: [String: Any] = [
            "keyCode": 17,
            "modifiers": 0,
            "sourceMode": "auto",
            "targetLanguageIdentifier": Locale.Language(identifier: "zh-Hans").maximalIdentifier,
            "translationBackend": "system"
        ]
        let data = try JSONSerialization.data(withJSONObject: legacyPayload)
        defaults.set(data, forKey: "morpho.app.settings")

        let loaded = store.load()

        XCTAssertEqual(loaded.translationProvider, .siliconFlow)
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "morpho.tests.settings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
