# Menu Bar Busy Indicator Implementation Plan

> **Status:** COMPLETED + TUNED (2026-03-28)

**Goal:** Replace the globe-cycling menu bar animation with a static globe + breathing dot overlay to indicate active translation.

**Architecture:** Rewrite `MenuBarIconStateMachine` to drive a breathing dot phase instead of cycling symbols. Compose the dot into the `NSImage` in `MorphoApp.menuBarIconImage()`. Add delay-show/min-display/fade-out timing in `MorphoAppModel`.

**Tech Stack:** Swift 6.2, SwiftUI MenuBarExtra, AppKit NSImage/CoreGraphics, XCTest

**Branch:** `feat/menu-bar-busy-indicator` (worktree: `.worktrees/feat-menu-bar-busy-indicator`)
**Commits:** `c50c3e3` (state machine rewrite), `a1c6975` (dot rendering + model integration), `aa3ac46` (visual tuning + race-condition hardening)
**Tests:** 98/98 passing

## Final Tuned Snapshot

> Note: the large code blocks below document the initial rollout path. Final production parameters are:

- Base symbol: `m.circle.fill`
- Icon render: `pointSize = 15`, `weight = .medium`, `canvas = 18x18`
- Dot render: `diameter = 7.2pt`, `inset = 0.25pt`, template mask color
- Breathing: `cycle = 1.35s`, `scale = 0.68...1.0`, `alpha = 0.58...1.0`
- Dot behavior: `200ms` delayed show, `350ms` minimum display, `150ms` fade-out
- Concurrency hardening: generation/token guard added so previous delay tasks cannot fade-out a newer translation indicator

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `Sources/MorphoApp/Support/MenuBarIconStateMachine.swift` | Rewrite | Breathing dot phase calculation, state transitions |
| `Sources/MorphoApp/MorphoApp.swift` | Modify | Composite NSImage rendering (base icon + dot) |
| `Sources/MorphoApp/MorphoAppModel.swift` | Modify | Timer management, delay/min-display timing, publish render state |
| `Tests/MorphoAppTests/Support/MenuBarIconStateMachineTests.swift` | Rewrite | Tests for new state machine behavior |

---

### Task 1: Rewrite MenuBarIconStateMachine with breathing dot logic

**Files:**
- Rewrite: `Sources/MorphoApp/Support/MenuBarIconStateMachine.swift`
- Rewrite: `Tests/MorphoAppTests/Support/MenuBarIconStateMachineTests.swift`

- [ ] **Step 1: Write the new state machine tests**

Replace `Tests/MorphoAppTests/Support/MenuBarIconStateMachineTests.swift` with:

```swift
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
        // Phase should have advanced
        XCTAssertNotEqual(before.dotScale, after.dotScale)
    }

    func testBreathingPhaseOscillatesBetweenMinAndMax() {
        var machine = MenuBarIconStateMachine()
        machine.beginTranslation()
        // Advance through a full cycle (1.25s)
        for _ in 0..<38 { // ~38 ticks at 33ms = 1.254s
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
        // Advance past fade-out duration (150ms)
        for _ in 0..<6 { // 6 * 33ms = 198ms > 150ms
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
        // Scale should be static at 1.0
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
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/zhengyuelin/Things/morpho && swift test --filter MenuBarIconStateMachineTests 2>&1 | tail -20`
Expected: Compilation errors (new API doesn't exist yet)

- [ ] **Step 3: Write the new MenuBarIconStateMachine**

Replace `Sources/MorphoApp/Support/MenuBarIconStateMachine.swift` with:

```swift
import Foundation

struct MenuBarIconRenderState: Equatable {
    let baseSymbol: String
    let dotScale: CGFloat?
    let dotAlpha: CGFloat
}

struct MenuBarIconStateMachine {
    static let breathingCycleDuration: TimeInterval = 1.25
    static let fadeOutDuration: TimeInterval = 0.15
    private static let baseSymbol = "globe.asia.australia.fill"
    private static let minScale: CGFloat = 0.82
    private static let maxScale: CGFloat = 1.0

    var reduceMotion: Bool = false

    private enum Phase {
        case idle
        case loading(elapsed: TimeInterval)
        case fadingOut(elapsed: TimeInterval, lastScale: CGFloat)
    }

    private var phase: Phase = .idle

    var isLoading: Bool {
        if case .loading = phase { return true }
        return false
    }

    var isFadingOut: Bool {
        if case .fadingOut = phase { return true }
        return false
    }

    var isAnimating: Bool {
        switch phase {
        case .idle: return false
        case .loading, .fadingOut: return true
        }
    }

    var renderState: MenuBarIconRenderState {
        switch phase {
        case .idle:
            return MenuBarIconRenderState(baseSymbol: Self.baseSymbol, dotScale: nil, dotAlpha: 0.0)
        case .loading(let elapsed):
            if reduceMotion {
                return MenuBarIconRenderState(baseSymbol: Self.baseSymbol, dotScale: 1.0, dotAlpha: 1.0)
            }
            let scale = Self.breathingScale(at: elapsed)
            let alpha = Self.breathingAlpha(at: elapsed)
            return MenuBarIconRenderState(baseSymbol: Self.baseSymbol, dotScale: scale, dotAlpha: alpha)
        case .fadingOut(let elapsed, let lastScale):
            let progress = min(elapsed / Self.fadeOutDuration, 1.0)
            let alpha = 1.0 - progress
            return MenuBarIconRenderState(baseSymbol: Self.baseSymbol, dotScale: lastScale, dotAlpha: alpha)
        }
    }

    mutating func beginTranslation() {
        phase = .loading(elapsed: 0)
    }

    mutating func animationTick(deltaSeconds: TimeInterval) {
        switch phase {
        case .idle:
            break
        case .loading(let elapsed):
            phase = .loading(elapsed: elapsed + deltaSeconds)
        case .fadingOut(let elapsed, let lastScale):
            let newElapsed = elapsed + deltaSeconds
            if newElapsed >= Self.fadeOutDuration {
                phase = .idle
            } else {
                phase = .fadingOut(elapsed: newElapsed, lastScale: lastScale)
            }
        }
    }

    mutating func finishTranslation() {
        let currentScale: CGFloat
        if case .loading(let elapsed) = phase {
            currentScale = reduceMotion ? 1.0 : Self.breathingScale(at: elapsed)
        } else {
            currentScale = Self.maxScale
        }
        phase = .fadingOut(elapsed: 0, lastScale: currentScale)
    }

    private static func breathingScale(at elapsed: TimeInterval) -> CGFloat {
        let t = elapsed / breathingCycleDuration
        let sine = sin(t * 2.0 * .pi)
        let normalized = (sine + 1.0) / 2.0 // 0...1
        return minScale + (maxScale - minScale) * normalized
    }

    private static func breathingAlpha(at elapsed: TimeInterval) -> CGFloat {
        let t = elapsed / breathingCycleDuration
        let sine = sin(t * 2.0 * .pi)
        let normalized = (sine + 1.0) / 2.0
        return 0.85 + 0.15 * normalized
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/zhengyuelin/Things/morpho && swift test --filter MenuBarIconStateMachineTests 2>&1 | tail -20`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add Sources/MorphoApp/Support/MenuBarIconStateMachine.swift Tests/MorphoAppTests/Support/MenuBarIconStateMachineTests.swift
git commit -m "refactor: rewrite MenuBarIconStateMachine with breathing dot phase"
```

---

### Task 2: Update MorphoApp to render composite NSImage with dot

**Files:**
- Modify: `Sources/MorphoApp/MorphoApp.swift`

- [ ] **Step 1: Update MorphoApp.swift to render dot overlay**

Replace the full content of `Sources/MorphoApp/MorphoApp.swift` with:

```swift
import AppKit
import SwiftUI

@main
struct MorphoApp: App {
    private static let canvasDimension: CGFloat = 18.0
    private static let iconSymbolPointSize: CGFloat = 13.0
    private static let menuBarIconSymbolConfiguration = NSImage.SymbolConfiguration(
        pointSize: iconSymbolPointSize,
        weight: .regular,
        scale: .medium
    )
    private static let dotBaseDiameter: CGFloat = 3.5
    private static let dotInset: CGFloat = 1.5
    private static let dotColor: NSColor = .systemGreen

    @StateObject private var model = MorphoAppModel()

    var body: some Scene {
        MenuBarExtra {
            MorphoMenuView(model: model)
                .environment(\.locale, interfaceLocale)
        } label: {
            Image(nsImage: menuBarIcon(for: model.menuBarIconRenderState))
                .accessibilityLabel("Morpho")
        }

        Settings {
            SettingsView(model: model)
                .environment(\.locale, interfaceLocale)
                .frame(width: 760, height: 560)
        }
        .windowResizability(.contentSize)
    }

    private var interfaceLocale: Locale {
        InterfaceLanguageOptions.locale(for: model.interfaceLanguageCode)
    }

    private func menuBarIcon(for state: MenuBarIconRenderState) -> NSImage {
        let canvas = NSSize(width: Self.canvasDimension, height: Self.canvasDimension)
        let image = NSImage(size: canvas, flipped: false) { rect in
            self.drawBaseIcon(state.baseSymbol, in: rect)
            if let dotScale = state.dotScale, state.dotAlpha > 0 {
                self.drawDot(scale: dotScale, alpha: state.dotAlpha, in: rect)
            }
            return true
        }
        image.isTemplate = state.dotScale == nil
        return image
    }

    private func drawBaseIcon(_ symbolName: String, in rect: NSRect) {
        let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Morpho")
            ?? NSImage(systemSymbolName: "globe.asia.australia.fill", accessibilityDescription: "Morpho")
            ?? NSImage()
        let configured = base.withSymbolConfiguration(Self.menuBarIconSymbolConfiguration) ?? base
        configured.isTemplate = true
        let iconSize = configured.size
        let origin = NSPoint(
            x: (rect.width - iconSize.width) / 2,
            y: (rect.height - iconSize.height) / 2
        )
        configured.draw(in: NSRect(origin: origin, size: iconSize))
    }

    private func drawDot(scale: CGFloat, alpha: CGFloat, in rect: NSRect) {
        let diameter = Self.dotBaseDiameter * scale
        let x = rect.maxX - Self.dotInset - diameter
        let y = rect.minY + Self.dotInset
        let dotRect = NSRect(x: x, y: y, width: diameter, height: diameter)
        let color = Self.dotColor.withAlphaComponent(alpha)
        color.setFill()
        let path = NSBezierPath(ovalIn: dotRect)
        path.fill()
    }
}
```

- [ ] **Step 2: Build to verify compilation**

Run: `cd /Users/zhengyuelin/Things/morpho && swift build 2>&1 | tail -20`
Expected: Compilation errors in `MorphoAppModel` (it still publishes `menuBarIconSystemImage: String` instead of `menuBarIconRenderState`)

This is expected — we fix it in Task 3.

---

### Task 3: Update MorphoAppModel for breathing dot timing and rendering

**Files:**
- Modify: `Sources/MorphoApp/MorphoAppModel.swift`

- [ ] **Step 1: Update MorphoAppModel published properties and state**

In `MorphoAppModel.swift`, make the following changes:

1. Replace the published property `menuBarIconSystemImage: String` with `menuBarIconRenderState: MenuBarIconRenderState`.

2. Replace the private state for animation timer and completion hold with delay-show / min-display timing.

3. Update `init()` to initialize the new property.

4. Rewrite the menu bar icon animation methods.

Full replacement of `MorphoAppModel.swift`:

```swift
import Combine
import Foundation
import MorphoKit

@MainActor
final class MorphoAppModel: ObservableObject {
    private static let supportedLanguageIdentifiers = LanguageOptions.all.map(\.id)
    private static let defaultSourceLanguage = Locale.Language(identifier: "en")
    private static let animationTimerInterval: TimeInterval = 0.033
    private static let delayBeforeShow: TimeInterval = 0.2
    private static let minimumDisplayDuration: TimeInterval = 0.35

    @Published private(set) var settings: AppSettings
    @Published private(set) var apiKey: String
    @Published private(set) var lastStatus: StatusEntry
    @Published private(set) var menuBarIconRenderState: MenuBarIconRenderState
    @Published private(set) var runHistoryEntries: [RunHistoryEntry]
    @Published private(set) var launchAtLoginErrorMessage: String?

    private let settingsStore: SettingsStore
    private let runHistoryStore: RunHistoryStore
    private let statusCenter: StatusCenter
    private let statusReporter: CompositeStatusReporter
    private let useCase: HandleHotkeyTranslationUseCase
    private let hotkeyService: GlobalHotkeyService?
    private let caretLoadingOverlay: CaretLoadingOverlay

    private var cancellables: Set<AnyCancellable> = []
    private var inFlightTranslationTask: Task<Void, Never>?
    private var menuBarIconStateMachine: MenuBarIconStateMachine
    private var menuBarIconAnimationTimer: Timer?
    private var dotDelayTimer: Timer?
    private var dotShownAt: Date?
    private var dotWasShown: Bool = false

    init() {
        let settingsStore = UserDefaultsSettingsStore()
        let runHistoryStore = FileRunHistoryStore()
        var menuBarIconStateMachine = MenuBarIconStateMachine()
        menuBarIconStateMachine.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        var initialSettings = settingsStore.load()
        if case .auto = initialSettings.sourceLanguage,
           initialSettings.autoSwitchLanguagePair == nil {
            initialSettings.autoSwitchLanguagePair = AppSettings.makeDefaultAutoSwitchLanguagePair(
                targetLanguage: initialSettings.targetLanguage
            )
        }
        initialSettings.launchAtLoginPreferred = LaunchAtLoginController.isEnabled()
        settingsStore.save(initialSettings)
        let statusCenter = StatusCenter()
        let statusReporter = CompositeStatusReporter(
            reporters: [statusCenter, UserNotificationStatusReporter()]
        )

        self.settingsStore = settingsStore
        self.runHistoryStore = runHistoryStore
        self.settings = initialSettings
        self.apiKey = initialSettings.translationAPIKey
        self.statusCenter = statusCenter
        self.statusReporter = statusReporter
        self.caretLoadingOverlay = CaretLoadingOverlay()
        self.lastStatus = StatusEntry(
            message: AppLocalization.string(
                "status.ready",
                locale: InterfaceLanguageOptions.locale(for: initialSettings.interfaceLanguageCode)
            ),
            severity: .info
        )
        self.menuBarIconStateMachine = menuBarIconStateMachine
        self.menuBarIconRenderState = menuBarIconStateMachine.renderState
        self.runHistoryEntries = runHistoryStore.load(limit: 200)
        self.launchAtLoginErrorMessage = nil

        let textGateway = LayeredTextContextGateway()
        let siliconFlowHTTPClient = RetryingCloudHTTPClient(
            wrapped: URLSessionCloudHTTPClient()
        )
        let siliconFlowEngine = CloudTranslationEngine(
            client: SiliconFlowTranslationProviderClient(httpClient: siliconFlowHTTPClient)
        )
        let engineFactory = DefaultTranslationEngineFactory(
            siliconFlowEngine: siliconFlowEngine
        )

        self.useCase = HandleHotkeyTranslationUseCase(
            permissionChecker: AccessibilityPermissionService(),
            contextProvider: textGateway,
            textReplacer: textGateway,
            settingsStore: settingsStore,
            engineFactory: engineFactory,
            statusSink: statusReporter,
            sourceLanguageDetector: NaturalLanguageSourceLanguageDetector(),
            runHistoryStore: runHistoryStore
        )

        do {
            let hotkeyService = try GlobalHotkeyService()
            self.hotkeyService = hotkeyService
        } catch {
            self.hotkeyService = nil
        }

        bindStatus()
        bindHotkey()
        registerHotkeyIfPossible()
        observeReduceMotionChanges()
    }

    func triggerTranslation() {
        guard inFlightTranslationTask == nil else {
            return
        }

        caretLoadingOverlay.show()
        startDotDelayTimer()

        inFlightTranslationTask = Task { [weak self] in
            guard let self else {
                return
            }

            defer {
                self.handleTranslationCompletion()
            }

            _ = await self.useCase.execute()
        }
    }

    func updateSourceLanguage(_ identifier: String) {
        let language = Locale.Language(identifier: identifier)

        if autoDetectEnabled {
            settings.autoSwitchLanguagePair = AutoSwitchLanguagePair(
                firstLanguage: language,
                secondLanguage: resolvedTargetLanguage()
            )
        } else {
            settings.sourceLanguage = .fixed(language)
        }

        persistAndApplySettings()
    }

    func updateTargetLanguage(_ identifier: String) {
        let language = Locale.Language(identifier: identifier)
        settings.targetLanguage = language

        if autoDetectEnabled {
            settings.autoSwitchLanguagePair = AutoSwitchLanguagePair(
                firstLanguage: resolvedSourceLanguage(),
                secondLanguage: language
            )
        }

        persistAndApplySettings()
    }

    func setAutoDetectEnabled(_ enabled: Bool) {
        let sourceLanguage = resolvedSourceLanguage()
        let targetLanguage = resolvedTargetLanguage()

        if enabled {
            settings.sourceLanguage = .auto
            settings.autoSwitchLanguagePair = AutoSwitchLanguagePair(
                firstLanguage: sourceLanguage,
                secondLanguage: targetLanguage
            )
        } else {
            settings.sourceLanguage = .fixed(sourceLanguage)
            settings.autoSwitchLanguagePair = nil
        }

        settings.targetLanguage = targetLanguage
        persistAndApplySettings()
    }

    func updateProvider(_ provider: TranslationProvider) {
        settings.translationProvider = provider
        persistAndApplySettings()
    }

    func updateTranslationModelID(_ modelID: String) {
        let trimmed = modelID.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.translationModelID = trimmed.isEmpty ? AppSettings.defaultTranslationModelID : trimmed
        persistSettings()
    }

    func updateLaunchAtLoginPreferred(_ preferred: Bool) {
        do {
            try LaunchAtLoginController.setEnabled(preferred)
            settings.launchAtLoginPreferred = LaunchAtLoginController.isEnabled()
            launchAtLoginErrorMessage = nil
            persistSettings()
        } catch {
            settings.launchAtLoginPreferred = LaunchAtLoginController.isEnabled()
            launchAtLoginErrorMessage = AppLocalization.format(
                "settings.general.launch_at_login.error",
                locale: interfaceLocale,
                launchAtLoginErrorReason(for: error)
            )
            persistSettings()
            statusReporter.publish(
                StatusEntry(
                    message: launchAtLoginErrorMessage
                        ?? AppLocalization.string(
                            "settings.general.launch_at_login.error_generic",
                            locale: interfaceLocale
                        ),
                    severity: .error
                )
            )
        }
    }

    func updateInterfaceLanguageCode(_ code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.interfaceLanguageCode = trimmed.isEmpty ? AppSettings.defaultInterfaceLanguageCode : trimmed
        persistSettings()
    }

    func updateAPIKey(_ value: String) {
        apiKey = value
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        apiKey = trimmed
        settings.translationAPIKey = trimmed
        persistSettings()
    }

    func updateHotkeyShortcut(_ shortcut: HotkeyShortcut) {
        settings.hotkey = shortcut
        persistAndApplySettings()
    }

    func setHotkeyEnabled(_ enabled: Bool) {
        settings.isHotkeyEnabled = enabled
        persistAndApplySettings()
    }

    var autoDetectEnabled: Bool {
        if case .auto = settings.sourceLanguage {
            return true
        }
        return false
    }

    var sourceLanguageIdentifier: String {
        LanguageIdentifierCodec.displayIdentifier(
            for: resolvedSourceLanguage(),
            supportedIdentifiers: Self.supportedLanguageIdentifiers
        )
    }

    var targetLanguageIdentifier: String {
        LanguageIdentifierCodec.displayIdentifier(
            for: resolvedTargetLanguage(),
            supportedIdentifiers: Self.supportedLanguageIdentifiers
        )
    }

    var hotkeySummary: String {
        HotkeyShortcutPresentation.summary(for: settings.hotkey)
    }

    var hotkeyEnabled: Bool {
        settings.isHotkeyEnabled
    }

    var launchAtLoginPreferred: Bool {
        settings.launchAtLoginPreferred
    }

    var interfaceLanguageCode: String {
        settings.interfaceLanguageCode
    }

    var translationModelID: String {
        settings.translationModelID
    }

    func refreshRunHistory(limit: Int = 200) {
        runHistoryEntries = runHistoryStore.load(limit: limit)
    }

    func clearRunHistory() {
        runHistoryStore.clear()
        runHistoryEntries = []
    }

    private func resolvedSourceLanguage() -> Locale.Language {
        if let pair = settings.autoSwitchLanguagePair {
            return pair.firstLanguage
        }

        switch settings.sourceLanguage {
        case .auto:
            return Self.defaultSourceLanguage
        case .fixed(let language):
            return language
        }
    }

    private func resolvedTargetLanguage() -> Locale.Language {
        settings.autoSwitchLanguagePair?.secondLanguage ?? settings.targetLanguage
    }

    private func bindStatus() {
        statusCenter.$lastEntry
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] entry in
                self?.lastStatus = entry
            }
            .store(in: &cancellables)
    }

    private func bindHotkey() {
        hotkeyService?.onHotkeyPressed = { [weak self] in
            Task { @MainActor in
                self?.triggerTranslation()
            }
        }
    }

    private func persistAndApplySettings() {
        persistSettings()
        registerHotkeyIfPossible()
    }

    private func persistSettings() {
        settingsStore.save(settings)
    }

    private func registerHotkeyIfPossible() {
        if !settings.isHotkeyEnabled {
            hotkeyService?.unregister()
            return
        }

        guard let hotkeyService else {
            statusReporter.publish(
                StatusEntry(
                    message: AppLocalization.string(
                        "status.hotkey.init_failed",
                        locale: interfaceLocale
                    ),
                    severity: .error
                )
            )
            return
        }

        do {
            try hotkeyService.register(settings.hotkey)
        } catch {
            statusReporter.publish(
                StatusEntry(
                    message: AppLocalization.string(
                        "status.hotkey.register_failed",
                        locale: interfaceLocale
                    ),
                    severity: .error
                )
            )
        }
    }

    private var interfaceLocale: Locale {
        InterfaceLanguageOptions.locale(for: settings.interfaceLanguageCode)
    }

    private func launchAtLoginErrorReason(for error: Error) -> String {
        guard let launchError = error as? LaunchAtLoginControllerError else {
            return error.localizedDescription
        }

        switch launchError {
        case .unsupportedSystem:
            return AppLocalization.string(
                "status.launch_at_login.unsupported_system",
                locale: interfaceLocale
            )
        case .registrationFailed(let reason):
            return reason
        }
    }

    // MARK: - Translation Completion & Dot Timing

    private func handleTranslationCompletion() {
        caretLoadingOverlay.hide()
        inFlightTranslationTask = nil
        refreshRunHistory()
        cancelDotDelayTimer()

        if dotWasShown {
            let elapsed = dotShownAt.map { Date().timeIntervalSince($0) } ?? Self.minimumDisplayDuration
            let remaining = Self.minimumDisplayDuration - elapsed
            if remaining > 0 {
                Task {
                    try? await Task.sleep(for: .seconds(remaining))
                    guard !Task.isCancelled else { return }
                    self.beginDotFadeOut()
                }
            } else {
                beginDotFadeOut()
            }
        } else {
            resetDotState()
        }
    }

    private func beginDotFadeOut() {
        menuBarIconStateMachine.finishTranslation()
        menuBarIconRenderState = menuBarIconStateMachine.renderState
        // Animation timer continues to drive fade-out; it will stop when idle
    }

    // MARK: - Dot Delay Timer

    private func startDotDelayTimer() {
        dotWasShown = false
        dotShownAt = nil
        dotDelayTimer = Timer.scheduledTimer(
            withTimeInterval: Self.delayBeforeShow,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showDotAfterDelay()
            }
        }
    }

    private func cancelDotDelayTimer() {
        dotDelayTimer?.invalidate()
        dotDelayTimer = nil
    }

    private func showDotAfterDelay() {
        guard inFlightTranslationTask != nil else {
            return
        }
        dotWasShown = true
        dotShownAt = Date()
        menuBarIconStateMachine.beginTranslation()
        menuBarIconRenderState = menuBarIconStateMachine.renderState
        startMenuBarIconAnimationTimer()
    }

    // MARK: - Animation Timer

    private func startMenuBarIconAnimationTimer() {
        stopMenuBarIconAnimationTimer()
        let timer = Timer(
            timeInterval: Self.animationTimerInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.advanceMenuBarIconAnimation()
            }
        }
        menuBarIconAnimationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopMenuBarIconAnimationTimer() {
        menuBarIconAnimationTimer?.invalidate()
        menuBarIconAnimationTimer = nil
    }

    private func advanceMenuBarIconAnimation() {
        menuBarIconStateMachine.animationTick(deltaSeconds: Self.animationTimerInterval)
        menuBarIconRenderState = menuBarIconStateMachine.renderState

        if !menuBarIconStateMachine.isAnimating {
            stopMenuBarIconAnimationTimer()
            resetDotState()
        }
    }

    private func resetDotState() {
        dotWasShown = false
        dotShownAt = nil
    }

    // MARK: - Reduce Motion

    private func observeReduceMotionChanges() {
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.menuBarIconStateMachine.reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            }
        }
    }
}
```

- [ ] **Step 2: Build and run tests**

Run: `cd /Users/zhengyuelin/Things/morpho && swift build 2>&1 | tail -30`
Expected: BUILD SUCCEEDED

Run: `cd /Users/zhengyuelin/Things/morpho && swift test 2>&1 | tail -30`
Expected: All tests pass

- [ ] **Step 3: Commit**

```bash
git add Sources/MorphoApp/MorphoApp.swift Sources/MorphoApp/MorphoAppModel.swift
git commit -m "feat: menu bar breathing dot indicator during translation"
```

---

### Task 4: Verify and fix any remaining references

**Files:**
- Check: Any file that references `menuBarIconSystemImage`

- [ ] **Step 1: Search for old property references**

Run: `cd /Users/zhengyuelin/Things/morpho && grep -r "menuBarIconSystemImage" Sources/ Tests/`

If any references remain (e.g., in `MorphoMenuView.swift`), update them.

- [ ] **Step 2: Full build and test**

Run: `cd /Users/zhengyuelin/Things/morpho && swift test 2>&1 | tail -30`
Expected: All tests pass, no warnings about `menuBarIconSystemImage`

- [ ] **Step 3: Commit if changes were needed**

```bash
git add -u
git commit -m "fix: remove stale menuBarIconSystemImage references"
```
