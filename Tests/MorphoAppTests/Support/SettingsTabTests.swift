import Foundation
import XCTest
@testable import MorphoApp

final class SettingsTabTests: XCTestCase {
    func testAllCasesContainWorkflowAndEngineTabs() {
        XCTAssertEqual(
            SettingsTab.allCases,
            [.general, .hotkey, .workflow, .engine, .history, .about]
        )
    }

    func testWorkflowTabUsesExpectedIcon() {
        XCTAssertEqual(SettingsTab.workflow.iconName, "arrow.triangle.swap")
    }

    func testEngineTabUsesExpectedIcon() {
        XCTAssertEqual(SettingsTab.engine.iconName, "waveform")
    }

    func testWorkflowTabUsesEnglishTranslation() {
        let value = SettingsTab.workflow.title(locale: Locale(identifier: "en"))

        XCTAssertEqual(value, "Workflow")
    }

    func testWorkflowTabUsesSimplifiedChineseTranslation() {
        let value = SettingsTab.workflow.title(locale: Locale(identifier: "zh-Hans"))

        XCTAssertEqual(value, "流程")
    }

    func testEngineTabUsesEnglishTranslation() {
        let value = SettingsTab.engine.title(locale: Locale(identifier: "en"))

        XCTAssertEqual(value, "Engine")
    }

    func testEngineTabUsesSimplifiedChineseTranslation() {
        let value = SettingsTab.engine.title(locale: Locale(identifier: "zh-Hans"))

        XCTAssertEqual(value, "引擎")
    }
}
