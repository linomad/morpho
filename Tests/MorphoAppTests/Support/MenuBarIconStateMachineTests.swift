import XCTest
@testable import MorphoApp

final class MenuBarIconStateMachineTests: XCTestCase {
    func testInitialStateIsIdle() {
        let machine = MenuBarIconStateMachine()
        let state = machine.renderState
        XCTAssertEqual(state.baseSymbol, "globe.asia.australia.fill")
        XCTAssertNil(state.dotScale)
        XCTAssertEqual(state.dotAlpha, 0.0)
    }

    func testBeginTranslationTransitionsToLoading() {
        var machine = MenuBarIconStateMachine()
        machine.beginTranslation()
        XCTAssertTrue(machine.isLoading)
    }

    func testAnimationTickAdvancesBreathingPhase() {
        var machine = MenuBarIconStateMachine()
        machine.beginTranslation()
        let before = machine.renderState
        machine.animationTick(deltaSeconds: 0.1)
        let after = machine.renderState
        XCTAssertNotNil(after.dotScale)
        XCTAssertNotEqual(before.dotScale, after.dotScale)
    }

    func testBreathingPhaseOscillatesBetweenMinAndMax() {
        var machine = MenuBarIconStateMachine()
        machine.beginTranslation()
        for _ in 0..<38 {
            machine.animationTick(deltaSeconds: 0.033)
        }
        let state = machine.renderState
        XCTAssertNotNil(state.dotScale)
        let scale = state.dotScale!
        XCTAssertGreaterThanOrEqual(scale, 0.82)
        XCTAssertLessThanOrEqual(scale, 1.0)
    }

    func testFinishTranslationBeginsFadeOut() {
        var machine = MenuBarIconStateMachine()
        machine.beginTranslation()
        machine.animationTick(deltaSeconds: 0.1)
        machine.finishTranslation()
        XCTAssertTrue(machine.isFadingOut)
    }

    func testFadeOutReducesAlpha() {
        var machine = MenuBarIconStateMachine()
        machine.beginTranslation()
        machine.animationTick(deltaSeconds: 0.1)
        machine.finishTranslation()
        let alphaBeforeFade = machine.renderState.dotAlpha
        machine.animationTick(deltaSeconds: 0.05)
        let alphaAfterFade = machine.renderState.dotAlpha
        XCTAssertLessThan(alphaAfterFade, alphaBeforeFade)
    }

    func testFadeOutCompletesAndReturnsToIdle() {
        var machine = MenuBarIconStateMachine()
        machine.beginTranslation()
        machine.animationTick(deltaSeconds: 0.1)
        machine.finishTranslation()
        for _ in 0..<6 {
            machine.animationTick(deltaSeconds: 0.033)
        }
        XCTAssertFalse(machine.isLoading)
        XCTAssertFalse(machine.isFadingOut)
        XCTAssertNil(machine.renderState.dotScale)
    }

    func testBaseSymbolNeverChanges() {
        var machine = MenuBarIconStateMachine()
        XCTAssertEqual(machine.renderState.baseSymbol, "globe.asia.australia.fill")
        machine.beginTranslation()
        XCTAssertEqual(machine.renderState.baseSymbol, "globe.asia.australia.fill")
        machine.animationTick(deltaSeconds: 0.5)
        XCTAssertEqual(machine.renderState.baseSymbol, "globe.asia.australia.fill")
        machine.finishTranslation()
        XCTAssertEqual(machine.renderState.baseSymbol, "globe.asia.australia.fill")
    }

    func testReduceMotionProducesStaticDot() {
        var machine = MenuBarIconStateMachine()
        machine.reduceMotion = true
        machine.beginTranslation()
        let state1 = machine.renderState
        machine.animationTick(deltaSeconds: 0.1)
        let state2 = machine.renderState
        XCTAssertEqual(state1.dotScale, 1.0)
        XCTAssertEqual(state2.dotScale, 1.0)
        XCTAssertEqual(state1.dotAlpha, 1.0)
    }

    func testAnimationTickDuringIdleIsNoOp() {
        var machine = MenuBarIconStateMachine()
        machine.animationTick(deltaSeconds: 0.1)
        XCTAssertNil(machine.renderState.dotScale)
    }
}
