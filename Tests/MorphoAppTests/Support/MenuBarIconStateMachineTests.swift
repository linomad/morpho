import XCTest
@testable import MorphoApp

final class MenuBarIconStateMachineTests: XCTestCase {
    func testBeginTranslationStartsFromFirstIconAndTogglesOnAnimationTicks() {
        var machine = MenuBarIconStateMachine()

        let startIcon = machine.beginTranslation()
        XCTAssertEqual(startIcon, "slider.horizontal.below.square.filled.and.square")

        let firstTickIcon = machine.animationTick()
        XCTAssertEqual(firstTickIcon, "slider.horizontal.below.square.and.square.filled")

        let secondTickIcon = machine.animationTick()
        XCTAssertEqual(secondTickIcon, "slider.horizontal.below.square.filled.and.square")
    }

    func testFinishTranslationPinsSecondIconAndReturnsToFirstAfterHoldTimeout() {
        var machine = MenuBarIconStateMachine()

        _ = machine.beginTranslation()
        let completionIcon = machine.finishTranslation()
        XCTAssertEqual(completionIcon, "slider.horizontal.below.square.and.square.filled")

        let idleIcon = machine.completionHoldTimeout()
        XCTAssertEqual(idleIcon, "slider.horizontal.below.square.filled.and.square")
        XCTAssertEqual(machine.currentSystemImage, "slider.horizontal.below.square.filled.and.square")
    }

    func testBeginTranslationDuringCompletionHoldRestartsAnimationFromFirstIcon() {
        var machine = MenuBarIconStateMachine()

        _ = machine.beginTranslation()
        _ = machine.finishTranslation()

        let restartedIcon = machine.beginTranslation()
        XCTAssertEqual(restartedIcon, "slider.horizontal.below.square.filled.and.square")
        XCTAssertEqual(machine.animationTick(), "slider.horizontal.below.square.and.square.filled")
    }
}
