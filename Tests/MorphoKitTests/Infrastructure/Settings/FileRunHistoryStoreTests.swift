import Foundation
import XCTest
@testable import MorphoKit

final class FileRunHistoryStoreTests: XCTestCase {
    func testAppendAndLoadReturnsNewestFirst() {
        let fileURL = uniqueHistoryFileURL()
        let store = FileRunHistoryStore(fileURL: fileURL, maxStoredEntries: 10)

        store.append(
            RunHistoryEntry(
                createdAt: Date(timeIntervalSince1970: 10),
                inputText: "older",
                outputText: "旧",
                sourceLanguageIdentifier: "en",
                targetLanguageIdentifier: "zh-Hans",
                translationProvider: .siliconFlow,
                translationModelID: "deepseek-ai/DeepSeek-V3"
            )
        )
        store.append(
            RunHistoryEntry(
                createdAt: Date(timeIntervalSince1970: 20),
                inputText: "newer",
                outputText: "新",
                sourceLanguageIdentifier: "en",
                targetLanguageIdentifier: "zh-Hans",
                translationProvider: .siliconFlow,
                translationModelID: "deepseek-ai/DeepSeek-V3"
            )
        )

        let entries = store.load(limit: 10)

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].inputText, "newer")
        XCTAssertEqual(entries[1].inputText, "older")
    }

    func testAppendTrimsToMaxStoredEntries() {
        let fileURL = uniqueHistoryFileURL()
        let store = FileRunHistoryStore(fileURL: fileURL, maxStoredEntries: 2)

        store.append(
            RunHistoryEntry(
                createdAt: Date(timeIntervalSince1970: 1),
                inputText: "one",
                outputText: "一",
                sourceLanguageIdentifier: "en",
                targetLanguageIdentifier: "zh-Hans",
                translationProvider: .siliconFlow,
                translationModelID: "deepseek-ai/DeepSeek-V3"
            )
        )
        store.append(
            RunHistoryEntry(
                createdAt: Date(timeIntervalSince1970: 2),
                inputText: "two",
                outputText: "二",
                sourceLanguageIdentifier: "en",
                targetLanguageIdentifier: "zh-Hans",
                translationProvider: .siliconFlow,
                translationModelID: "deepseek-ai/DeepSeek-V3"
            )
        )
        store.append(
            RunHistoryEntry(
                createdAt: Date(timeIntervalSince1970: 3),
                inputText: "three",
                outputText: "三",
                sourceLanguageIdentifier: "en",
                targetLanguageIdentifier: "zh-Hans",
                translationProvider: .siliconFlow,
                translationModelID: "deepseek-ai/DeepSeek-V3"
            )
        )

        let entries = store.load(limit: 10)

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].inputText, "three")
        XCTAssertEqual(entries[1].inputText, "two")
    }

    func testClearRemovesAllEntries() {
        let fileURL = uniqueHistoryFileURL()
        let store = FileRunHistoryStore(fileURL: fileURL, maxStoredEntries: 5)

        store.append(
            RunHistoryEntry(
                createdAt: Date(),
                inputText: "hello",
                outputText: "你好",
                sourceLanguageIdentifier: "en",
                targetLanguageIdentifier: "zh-Hans",
                translationProvider: .siliconFlow,
                translationModelID: "deepseek-ai/DeepSeek-V3"
            )
        )

        store.clear()

        XCTAssertTrue(store.load(limit: 10).isEmpty)
    }

    private func uniqueHistoryFileURL() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("morpho.tests.history.\(UUID().uuidString)", isDirectory: true)
        return directory.appendingPathComponent("run-history.json")
    }
}
