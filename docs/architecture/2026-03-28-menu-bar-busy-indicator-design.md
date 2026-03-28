# Menu Bar Busy Indicator Design

**Date:** 2026-03-28
**Status:** Implemented (2026-03-28, tuned)
**Reference:** docs/research/sinan-chatgpt-202603282056-*.md

## Goal

When translation starts, show a breathing dot at the bottom-right corner of the menu bar icon. When translation ends, hide it. The menu bar icon's occupied space must never change.

## Current State

- App uses SwiftUI `MenuBarExtra` with SF Symbol icons (globe variants)
- During translation, the globe icon cycles through 3 symbols every 0.45s
- After completion, icon freezes on last frame for 3s, then returns to idle
- Managed by `MenuBarIconStateMachine` + timer in `MorphoAppModel`

## New Behavior

Replace globe-cycling animation with a **static app symbol + breathing dot** overlay.

### State Machine

| State | Icon | Dot |
|-------|------|-----|
| `idle` | `m.circle.fill` | Hidden |
| `loading` | `m.circle.fill` (same) | Visible, breathing animation |

No separate success/error states in the icon — errors are communicated via menu text and notifications (already implemented).

### Timing Rules

| Parameter | Value | Reason |
|-----------|-------|--------|
| Delay before show | 200ms | Skip dot for fast translations |
| Minimum display | 350ms | Prevent flash-on-flash-off |
| Fade-out duration | 150ms | Smooth disappearance (alpha ramp) |
| Breathing cycle | 1.35s | Calm, non-intrusive rhythm |

### Breathing Animation

- **Type:** Sinusoidal scale oscillation
- **Scale range:** 0.68x ↔ 1.0x (of base dot diameter)
- **Alpha range:** 0.58 ↔ 1.0
- **Curve:** `sin()` based — smooth ease-in-ease-out naturally
- **Timer interval:** ~33ms (30fps) — sufficient for smooth scale animation

### Dot Visual Spec

- **Position:** Bottom-right of icon canvas, inset ~0.25pt from edge
- **Base diameter:** 7.2pt
- **Shape:** Circle
- **Color:** Template mask (`.black`) so system tint adapts to menu bar context
- **No shadow**

### Canvas Spec

- **Fixed size:** 18×18pt (up from 15.5 to accommodate dot with margin)
- **SF Symbol:** Rendered at pointSize 15, weight `.medium`, centered in canvas
- **Both idle and loading states use identical canvas size** — no layout shift

### Reduce Motion Support

When `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` is `true`:
- Dot is shown **statically** at full size (scale 1.0, alpha 1.0)
- No breathing animation, no scale oscillation
- Show/hide timing rules still apply (delay, minimum display)

## Architecture

### Modified Files

1. **`MenuBarIconStateMachine.swift`** — Rewrite
   - Remove globe-cycling logic
   - Add `breathingPhase: CGFloat` driven by animation ticks
   - Add delay-show / min-display / fade-out timing logic
   - Output: `MenuBarIconRenderState` struct

2. **`MorphoApp.swift`** — Modify `menuBarIconImage()`
   - Accept render state instead of just symbol name
   - Composite dot onto SF Symbol image when loading
   - Fixed 18×18pt canvas

3. **`MorphoAppModel.swift`** — Modify animation management
   - Change timer interval from 0.45s to 0.033s during loading
   - Remove completion-hold (3s) logic — replaced by fade-out
   - Publish `MenuBarIconRenderState` instead of `String`

### Data Flow

```
triggerTranslation()
  → start 200ms delay timer
  → if still translating after 200ms:
      → start 30fps animation timer
      → each tick: advance breathingPhase, recompose NSImage
  → translation completes:
      → if dot never shown: done
      → if dot shown < 350ms: wait until 350ms, then fade out
      → fade out over 150ms (alpha ramp in render), then stop timer
```

### Render Pipeline

```
MenuBarIconRenderState {
    baseSymbol: String        // always "m.circle.fill"
    dotScale: CGFloat?        // nil = no dot, 0.68...1.0 = breathing
    dotAlpha: CGFloat         // 0.0...1.0 (for fade-out)
}
    ↓
menuBarIconImage(state:) → NSImage(18×18)
    1. Draw SF Symbol centered
    2. If dotScale != nil: draw circle at bottom-right
    ↓
Image(nsImage:) in MenuBarExtra label
```

## What This Does NOT Change

- Menu popover content (`MorphoMenuView`)
- Status text display (already shows "Translating..." / result)
- Caret loading overlay (independent feedback channel)
- Error handling / notifications
- Settings UI
- Translation logic
