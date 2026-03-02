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
            translationBackend: .system
        )

        store.save(settings)

        guard let data = defaults.data(forKey: "morpho.app.settings") else {
            XCTFail("Expected persisted settings data.")
            return
        }

        let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(raw["sourceLanguageIdentifier"] as? String, Locale.Language(identifier: "zh-Hant").maximalIdentifier)
        XCTAssertEqual(raw["targetLanguageIdentifier"] as? String, Locale.Language(identifier: "zh-Hans").maximalIdentifier)
    }

    func testLoadRestoresTraditionalChineseSourceLanguageSelection() {
        let defaults = makeIsolatedDefaults()
        let store = UserDefaultsSettingsStore(defaults: defaults)
        let settings = AppSettings(
            hotkey: .defaultValue,
            sourceLanguage: .fixed(Locale.Language(identifier: "zh-Hant")),
            targetLanguage: Locale.Language(identifier: "en"),
            translationBackend: .system
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
    }

    private func makeIsolatedDefaults() -> UserDefaults {
        let suiteName = "morpho.tests.settings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
