import XCTest
@testable import MorphoApp

final class MenuBarIconStateMachineTests: XCTestCase {
    func testInitialIconUsesIdleGlobeSymbol() {
        let machine = MenuBarIconStateMachine()
        XCTAssertEqual(machine.currentSystemImage, "globe.asia.australia.fill")
    }

    func testBeginTranslationCyclesThroughConfiguredRunningGlobeSymbols() {
        var machine = MenuBarIconStateMachine()

        let startIcon = machine.beginTranslation()
        XCTAssertEqual(startIcon, "globe.central.south.asia.fill")

        let firstTickIcon = machine.animationTick()
        XCTAssertEqual(firstTickIcon, "globe.central.south.asia.fill")

        let secondTickIcon = machine.animationTick()
        XCTAssertEqual(secondTickIcon, "globe.americas.fill")

        let thirdTickIcon = machine.animationTick()
        XCTAssertEqual(thirdTickIcon, "globe.central.south.asia.fill")
    }

    func testFinishTranslationPinsLastRunningIconAndReturnsToIdleAfterHoldTimeout() {
        var machine = MenuBarIconStateMachine()

        _ = machine.beginTranslation()
        let completionIcon = machine.finishTranslation()
        XCTAssertEqual(completionIcon, "globe.americas.fill")

        let idleIcon = machine.completionHoldTimeout()
        XCTAssertEqual(idleIcon, "globe.asia.australia.fill")
        XCTAssertEqual(machine.currentSystemImage, "globe.asia.australia.fill")
    }

    func testBeginTranslationDuringCompletionHoldRestartsFromFirstRunningIcon() {
        var machine = MenuBarIconStateMachine()

        _ = machine.beginTranslation()
        _ = machine.finishTranslation()

        let restartedIcon = machine.beginTranslation()
        XCTAssertEqual(restartedIcon, "globe.central.south.asia.fill")
        XCTAssertEqual(machine.animationTick(), "globe.central.south.asia.fill")
    }
}
