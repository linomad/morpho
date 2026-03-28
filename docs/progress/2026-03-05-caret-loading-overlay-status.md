# Caret Loading Overlay — Feature Status

**Branch:** `feat-caret-loading-overlay`
**Original plan:** `docs/plans/2026-03-05-hotkey-loading-feedback-design.md`
**Status:** Functionally complete, merged to main

---

## Feature Description

When the user triggers translation via the global hotkey, a small spinning overlay appears next to the text insertion caret to indicate that translation is in progress. It disappears automatically when translation completes (success or failure).

This provides in-context visual feedback without activating the Morpho window or stealing focus from the current application.

---

## Implementation Summary

### New Files

| File | Description |
|------|-------------|
| `Sources/MorphoApp/Support/CaretLoadingOverlay.swift` | NSPanel-based floating spinner. 14×14px arc animation, 20% opacity, 6px offset from caret. |
| `Sources/MorphoApp/Support/CaretRectLocator.swift` | Queries the text insertion caret position via macOS Accessibility API. Two-path fallback with multi-screen support. |
| `Tests/MorphoAppTests/Support/CaretOverlayGeometryTests.swift` | 13 tests covering size, spacing, stroke, opacity, color, positioning, and screen-edge clamping. |
| `Tests/MorphoAppTests/Support/CaretRectValidationTests.swift` | 6 tests covering coordinate conversion, screen boundary validation, and edge cases. |

### Modified Files

| File | Change |
|------|--------|
| `Sources/MorphoApp/MorphoAppModel.swift` | Added `caretLoadingOverlay` instance; calls `.show()` on translation start and `.hide()` in `handleTranslationCompletion()`. |

### How It Works

1. User presses hotkey → `MorphoAppModel.triggerTranslation()` runs
2. `caretLoadingOverlay.show()` queries caret rect via `CaretRectLocator`
3. If caret position is found, a non-activating `NSPanel` with a `CAShapeLayer` arc spinner appears at screen coordinates 6px to the right of the caret, vertically centered
4. Translation executes asynchronously
5. `handleTranslationCompletion()` calls `caretLoadingOverlay.hide()` regardless of success or failure

---

## Deviations from Original Plan

The plan specified a layered architecture with protocol abstractions. The implementation took a simpler direct approach:

| Plan | Implemented |
|------|-------------|
| `TranslationActivityIndicating` protocol + `TranslationActivityIndicatorController` | Not implemented. MorphoAppModel calls `.show()/.hide()` directly. |
| `FloatingLoadingHUDController` + SwiftUI `LoadingHUDView` with `ProgressView` and "Translating…" label | Not implemented. Replaced by a single `CaretLoadingOverlay` using CAShapeLayer. |
| HUD positioned near mouse cursor | Implemented near text caret instead (more precise and contextually relevant). |
| `HUDWindowControlling` protocol | Not implemented. No abstraction over the NSPanel. |

**Rationale:** The direct approach is lighter-weight and adequate for the current single-use case. The abstraction layers would add maintainability value if the overlay needed to be independently testable from MorphoAppModel or reused across multiple callsites — neither of which applies now.

---

## Known Gaps / Future Work

- **No protocol abstraction over `CaretLoadingOverlay`:** MorphoAppModel directly holds a concrete instance, which makes it difficult to mock the overlay in unit tests for the model.
- **Silent failure on caret detection:** If `CaretRectLocator.queryCaretRect()` returns nil (e.g., unsupported app or secure input field), the overlay silently does not appear. No log, no fallback.
- **No integration test for show/hide lifecycle:** Tests cover geometry and caret validation only. There is no test that verifies the overlay is shown/hidden in response to `triggerTranslation()`.
- **No timeout/watchdog:** If translation hangs, the overlay stays visible indefinitely. The existing `inFlightTranslationTask` guard prevents a second overlay but does not bound the first.

---

## Test Results

All 19 tests passing:
- `CaretOverlayGeometryTests` — 13 tests
- `CaretRectValidationTests` — 6 tests
