# Capturing and replacing text in any macOS input field

**The Accessibility API (AXUIElement) is the strongest foundation for programmatic text capture on macOS, but no single technique works universally.** Production apps like PopClip, Easydict, and Raycast all use a cascading hybrid strategy: try the Accessibility API first (sub-millisecond, no side effects), fall back to programmatic menu-bar copy, then to simulated ⌘C with clipboard save/restore. A recently discovered "menu action copy" technique — triggering Edit → Copy via the Accessibility tree rather than simulating keystrokes — eliminates the alert sounds and menu flashing that plagued earlier approaches. This report covers nine distinct technical approaches, their compatibility across app frameworks, macOS permission requirements, and the specific implementation patterns used by shipping translation tools.

---

## Accessibility API delivers fast, clean text capture in most native apps

The AXUIElement API from the ApplicationServices framework is the primary mechanism. The core flow creates a system-wide element, retrieves the focused UI element, then reads or writes text attributes directly.

**Reading text** requires two key attributes: `kAXSelectedTextAttribute` returns only the highlighted text, while `kAXValueAttribute` returns the full field contents. `kAXSelectedTextRangeAttribute` provides the selection's `{location, length}` as a `CFRange`. To check whether anything is selected, read the range and test if `length > 0`; if nothing is selected, fall back to reading `kAXValueAttribute` for the entire field.

**Writing text back** is equally direct. Setting `kAXSelectedTextAttribute` replaces only the current selection with new text — exactly the behavior a translation app needs. Setting `kAXValueAttribute` replaces the entire field. A third option, `kAXReplaceRangeWithTextParameterizedAttribute`, allows replacing an arbitrary range without changing the selection first, though support varies by app. Always call `AXUIElementIsAttributeSettable` before writing to verify the target element accepts modifications.

**Performance is excellent.** Benchmarks from Hammerspoon testing show attribute reads completing in ~0.07ms and writes in ~0.72ms — imperceptible to users and fast enough for real-time workflows.

**Enabling accessibility in non-native apps** requires setting special attributes on the application element. For Chromium-based browsers (Chrome, Edge, Brave), set `AXEnhancedUserInterface` to `true` on the `AXUIElementCreateApplication(pid)` element. For Electron apps (VS Code, Slack, Discord), set `AXManualAccessibility` to `true`. Without these flags, these apps expose no accessibility tree for their web content. Note that setting `AXEnhancedUserInterface` on Chrome has been reported to break window positioning and animations in some versions.

### Compatibility matrix for AXUIElement text operations

| App framework | Read AXValue | Read AXSelectedText | Write AXSelectedText | AXSelectedTextRange | Notes |
|---|---|---|---|---|---|
| Native Cocoa (AppKit) | ✅ Full | ✅ Full | ✅ Full | ✅ Full | Best support — TextEdit, Notes, Xcode, Mail |
| Safari / WebKit | ✅ Auto | ✅ Works | ⚠️ Most inputs | ✅ Works | Best browser; `contenteditable` well-supported |
| Chrome / Chromium | ⚠️ Needs AXEnhancedUI | ⚠️ After enable | ⚠️ Varies by input | ⚠️ May work | Web `<input>` and `<textarea>` generally work |
| Electron apps | ⚠️ Needs AXManualAccessibility | ⚠️ After enable | ⚠️ Unreliable | ❌ Always `{0,0}` | Fundamental cursor-position limitation |
| Qt apps | ✅ Standard widgets | ✅ Standard widgets | ⚠️ Varies | ⚠️ Varies | Custom widgets may not expose text |
| Java / Swing | ❌ Poor | ❌ Poor | ❌ Poor | ❌ Poor | Java Access Bridge is very limited |
| Terminal emulators | ❌ Limited | ❌ Limited | ❌ Limited | ❌ Limited | Custom rendering, not standard text fields |

The **Electron limitation is critical**: `AXSelectedTextRange` always returns `{location: 0, length: 0}` regardless of actual cursor position, because Apple considers it a private API and Electron doesn't implement it for App Store compliance. Reading `AXSelectedText` does work after enabling `AXManualAccessibility`, but you cannot programmatically determine *where* in the field the selection sits. Electron also has documented off-by-one bugs in character range calculations when lines start with whitespace.

---

## The menu-action copy technique is the most significant recent innovation

The Chinese macOS translation tool community recently discovered a clever approach that eliminates the two worst side effects of simulated ⌘C: **menu bar icon flashing** and **system alert sounds**. Instead of posting CGEvent keyboard events, this technique uses the Accessibility API to traverse the target app's menu bar, locate Edit → Copy, and perform the `AXPress` action on it programmatically.

This approach, first implemented in the **Copi** app (s1ntoneli/Copi) and adopted by **Easydict** (tisfeng/Easydict), works by walking the AX tree: application element → menu bar → Edit menu → Copy menu item → `AXUIElementPerformAction(kAXPressAction)`. The result is identical to the user clicking Edit → Copy — the selected text lands on the clipboard — but without simulating keyboard events. No flash, no sound, better performance.

Easydict's release notes describe the motivation: since many apps don't support direct `kAXSelectedTextAttribute` reading, developers previously had no choice but simulated ⌘C. The menu-action approach offers a middle ground between the clean Accessibility read path and the side-effect-heavy keystroke simulation. It still uses the clipboard (requiring save/restore), but avoids the UX problems that made the shortcut approach feel hacky.

---

## Clipboard-based capture works universally but demands careful handling

The NSPasteboard approach — save clipboard, simulate copy, read, translate, write, simulate paste, restore — is the universal fallback. It works in virtually every app that supports ⌘C/⌘V, including Electron apps, Chrome web pages, terminal emulators, and Java applications where the Accessibility API fails entirely.

**Saving and restoring the clipboard** is more complex than it appears. `NSPasteboard.general.pasteboardItems` returns an array of `NSPasteboardItem` objects, each containing multiple type representations (plain text, RTF, HTML, images, file URLs). A robust save iterates all items and all types, copying raw `Data` for each. The critical failure case is **promised data** (`NSFilePromiseProvider`): these lazy-evaluated clipboard entries cannot be reliably saved and restored because the promise callback is owned by the source app. Accessing certain promise types (like `com.apple.pasteboard.promised-suggested-file-name`) can cause indefinite hangs.

**Detecting clipboard readiness** after simulating ⌘C requires polling `NSPasteboard.general.changeCount`. A fixed delay is unreliable — apps populate the clipboard at different speeds. The correct pattern checks `changeCount` in a polling loop with 50ms intervals and a ~1-second timeout:

```swift
let previousCount = NSPasteboard.general.changeCount
simulateCopy() // Post ⌘C via CGEvent
var attempts = 0
while NSPasteboard.general.changeCount == previousCount && attempts < 20 {
    Thread.sleep(forTimeInterval: 0.05)
    attempts += 1
}
```

**Clipboard manager interference** is a real concern. Tools like Maccy, Paste, and CopyPaste Pro poll `changeCount` every 100–500ms and will capture your intermediate clipboard states. The community convention from nspasteboard.org provides mitigation: write `org.nspasteboard.TransientType` as an empty `Data` entry alongside your temporary clipboard content. Well-behaved clipboard managers (Maccy, Keyboard Maestro, Typinator, TextExpander) honor this flag and skip transient entries. Also mark content with `org.nspasteboard.AutoGeneratedType` to signal it wasn't user-initiated.

**Universal Clipboard** (Handoff) creates another edge case: temporary clipboard writes may sync to nearby iOS devices via Bluetooth/Wi-Fi. There is no API to selectively disable this for specific writes.

---

## CGEvent taps enable hotkey detection and keystroke simulation

CGEvent taps serve two roles in a translation app: monitoring mouse events to detect text selection (like PopClip does), and simulating keyboard shortcuts for copy/paste operations. `CGEvent.tapCreate` installs a callback at the HID, session, or annotated-session level to intercept or observe input events.

**For simulating keystrokes**, use `CGEventPost` with the `.cghidEventTap` location. The virtual key codes are **0x08** for C and **0x09** for V, with `.maskCommand` flags. Events must be posted as keyDown/keyUp pairs. A critical implementation detail: the callback for active event taps must return quickly — macOS disables taps that take longer than ~2 seconds, sending a `kCGEventTapDisabledByTimeout` event. Re-enable with `CGEventTapEnable(tap, true)`.

**Permission requirements split across two TCC categories.** Posting events (CGEventPost) requires **Accessibility** permission. Monitoring events (listen-only taps) requires **Input Monitoring** permission, which became a separate TCC category in macOS 10.15 Catalina. Check monitoring access with `CGPreflightListenEventAccess()` and request it with `CGRequestListenEventAccess()`. Both permissions require non-sandboxed distribution — `CGEventPost` is explicitly blocked by App Sandbox, as Apple's DTS engineer confirmed: "CGEventPost is not going to happen because that would allow an app to easily escape its sandbox."

**Secure Input mode** (`EnableSecureEventInput()`) blocks all event tap keyboard monitoring when active. Password fields, Terminal.app's "Secure Keyboard Entry" mode, and password managers like 1Password activate it. Detect with `IsSecureEventInputEnabled()`. A common annoyance: secure input can get "stuck" when apps crash without calling `DisableSecureEventInput()` or when `loginwindow` doesn't properly clean up after login. The fix is usually locking the screen (⌃⌘Q) and logging back in.

---

## InputMethodKit is a poor fit; Services Menu is clean but limited

**InputMethodKit (IMK)** allows building custom input methods, but it's fundamentally designed for text composition (CJK-style), not text transformation. The `IMKTextInput` protocol theoretically provides `selectedRange` and `attributedSubstringFromRange:` to read existing text, but Apple's own headers warn: "Many applications do not support these, so input methods should be prepared for these methods to return nil or NSNotFound." The user must switch to the custom input method in System Settings, creating unacceptable UX friction for a translation app. Input methods also require special installation in `/Library/Input Methods/` and often need logout/login to activate. **Verdict: avoid this approach.**

**macOS Services Menu** is underappreciated and technically elegant. A service registered via `NSServices` in Info.plist receives selected text on a private pasteboard (not the system clipboard), processes it, and writes replacement text back — the source app then replaces the selection in-place automatically. No clipboard pollution, no keystroke simulation, no permission prompts (Services don't require Accessibility permission). Configuration uses `NSSendTypes` and `NSReturnTypes` arrays in the plist; when `NSReturnTypes` is present, the originating app accepts returned text as a replacement.

The limitation is **compatibility**: Services work automatically in Cocoa/AppKit apps (TextEdit, Notes, Xcode, Safari text fields, Mail) but **not in Electron apps or Chrome web page content**. Electron has had an open feature request (#8394) since 2017 for Services integration with no resolution. Chrome's address bar works (native Cocoa) but web page text does not. Services also cannot be triggered programmatically — the user must invoke them via the Services menu, context menu, or a keyboard shortcut configured in System Settings. For a translation app that wants a global hotkey workflow, Services alone won't suffice, but they provide an excellent supplementary channel for native apps.

---

## AppleScript fills browser gaps, especially for Safari

AppleScript and JXA (JavaScript for Automation) shine in one critical area: **browser JavaScript execution**. Safari's `do JavaScript` command lets you run `window.getSelection().toString()` directly in the active tab, which is more reliable than Accessibility API for reading web page selections. Chrome supports the same pattern, though it requires the user to enable "Allow JavaScript in Apple Events" in the browser's developer menu.

```applescript
tell application "Safari"
    set selectedText to (do JavaScript "window.getSelection().toString()" in current tab of front window)
end tell
```

For non-browser apps, AppleScript's `System Events` can read `AXSelectedText` from the focused UI element — but this is just a slower wrapper around the same Accessibility API. App-specific scripting dictionaries (TextEdit, Microsoft Word, BBEdit) provide richer access to document content including setting text, but each app's dictionary is different, and many apps (VS Code, Slack, all Electron apps) have no scripting support at all.

**TCC overhead is significant.** Since macOS 10.14, each target app triggers a separate Automation permission dialog ("Your app wants to control System Events / Safari / Chrome"). Users see multiple permission prompts. AppleScript execution via `NSAppleScript` takes ~50–100ms for compilation; spawning `osascript` as a subprocess adds 200–500ms overhead. JXA offers identical capabilities with JavaScript syntax but has been effectively abandoned by Apple since 2016 — it works but receives no updates or documentation improvements.

---

## TCC permissions and Secure Input define the security boundaries

The translation app needs **Accessibility permission** (`kTCCServiceAccessibility`) as its primary requirement. This single permission unlocks AXUIElement text reading/writing, CGEvent posting for keystroke simulation, and active event taps. Check with `AXIsProcessTrusted()`; prompt with `AXIsProcessTrustedWithOptions` passing `kAXTrustedCheckOptionPrompt: true`. If also using AppleScript, you'll need separate **Automation permission** (`kTCCServiceAppleEvents`) per target app. If monitoring keystrokes for a global hotkey, you'll need **Input Monitoring** (`kTCCServiceListenEvent`).

### TCC evolution across macOS versions

| Version | Key change |
|---|---|
| 10.14 Mojave | Automation permission added; TCC greatly expanded |
| 10.15 Catalina | Input Monitoring separated from Accessibility; listen-only taps need their own permission |
| 11 Big Sur | OS updates can invalidate permissions if code signature changes |
| 13 Ventura | TCC database fully SIP-protected; no manual database editing possible |
| 14 Sonoma | Sporadic TCC inconsistencies reported (trusted but API calls fail; reboot fixes) |
| 15 Sequoia | Weekly re-prompts for Screen Recording (not Accessibility); stricter notarization |

**Accessibility APIs are incompatible with App Sandbox.** Apple's DTS has confirmed this explicitly. Apps needing AXUIElement access to other processes must distribute outside the Mac App Store via Developer ID signing and notarization. This applies to every production translation/text-capture app researched: PopClip, Raycast, Easydict, Bob, and Hammerspoon all require non-sandboxed distribution or have separate non-sandboxed editions.

A known pain point: TCC permissions can become corrupted, where `AXIsProcessTrusted()` returns `true` but API calls return `.apiDisabled`. The fix is removing the app from the Accessibility list and re-adding it, or rebooting. During development, code signature changes between builds can silently invalidate the permission grant.

---

## No secret private APIs exist for text capture

Research across English and Chinese developer communities reveals **no hidden private APIs** that magically solve text capture. PopClip, widely regarded as the fastest text-selection tool on macOS, uses only public APIs: CGEvent taps for mouse monitoring and AXUIElement for text reading. Its speed comes from the synchronous nature of event tap callbacks (~0.07ms for an AX attribute read), not from private interfaces.

The documented private APIs in this space are narrow in scope:

- **`_AXUIElementGetWindow`**: Returns the `CGWindowID` for a UI element. Used by window managers like AltTab, not relevant to text capture.
- **AXTextMarker / AXTextMarkerRange**: Private HIServices functions for precise text navigation in WebKit-based apps. Hammerspoon's `hs.axuielement.axtextmarker` module wraps these. They enable fine-grained text range operations in Safari and Apple's apps but are fragile across macOS versions.
- **HIToolbox / TSMDocumentAccess**: The underlying Carbon protocol that InputMethodKit wraps. Provides no additional text capture capabilities beyond what the public IMK/AX APIs expose.

The Easydict developer community explored these options extensively and concluded the same: the public Accessibility API + clipboard fallback pattern is what every shipping app uses.

---

## How production translation apps implement their pipelines

**Easydict** (open source, 10.7k GitHub stars) provides the most transparent implementation through its extracted **SelectedTextKit** library. It defines five strategies in a cascade:

1. **Accessibility** — `kAXSelectedTextAttribute` direct read (fastest, cleanest)
2. **AppleScript** — `window.getSelection().toString()` via browser JavaScript execution (critical for Safari)
3. **Menu action** — AX tree traversal to trigger Edit → Copy programmatically (no sound/flash)
4. **Shortcut** — Simulated ⌘C via CGEvent with automatic Alert sound muting and clipboard save/restore
5. **Auto** — Intelligent fallback: `accessibility → menuAction` for most apps; `appleScript → accessibility → menuAction → shortcut` for browsers

The **KeySender** library handles CGEvent simulation, and **AXSwift** provides the Accessibility API wrapper. When simulating ⌘C, Easydict temporarily mutes only the system Alert sound volume (not media playback) before posting the keyboard event, then restores it — a clever UX touch.

**PopClip** uses a simpler two-strategy approach: AXUIElement first, clipboard-based ⌘C fallback second. Its distinctive feature is mouse-event-driven activation — a CGEvent tap watches for `leftMouseUp` after drag, double-click, or triple-click, then immediately reads `kAXSelectedTextAttribute`. If AX returns nothing, it falls back to clipboard. PopClip does not respond to keyboard-only selections (⇧+Arrow) unless triggered via hotkey.

**Raycast** exposes `getSelectedText()` in its extension API, backed by AXUIElement + Accessibility permission. For text replacement (snippets, AI rewrites), it uses clipboard-based paste: write to `NSPasteboard.general`, simulate ⌘V via CGEventPost.

**OpenAI Translator** (Tauri/Rust desktop app) uses Rust native bindings to macOS Accessibility APIs via the `node-get-selected-text` library pattern: try AX first, fall back to simulated ⌘C with Alert sound muting. It also integrates with PopClip as an extension, outsourcing text capture to PopClip's mature pipeline.

---

## A recommended production-ready hybrid architecture

The optimal approach layers five strategies with intelligent app-aware routing:

**Layer 1 — App detection.** Identify the frontmost app's bundle identifier and framework. Maintain a lookup table mapping bundle IDs to optimal strategies. For Chrome/Chromium apps, set `AXEnhancedUserInterface = true`. For Electron apps, set `AXManualAccessibility = true`. For Safari, route directly to the AppleScript strategy.

**Layer 2 — Accessibility API (primary).** Attempt `kAXSelectedTextAttribute` on the focused element. If it returns non-empty text, proceed to translation. For replacement, try `AXUIElementSetAttributeValue` with `kAXSelectedTextAttribute` — check settability first with `AXUIElementIsAttributeSettable`. This path is sub-millisecond and touches nothing outside the target element.

**Layer 3 — AppleScript browser bridge.** For Safari, Chrome, and Firefox, execute `window.getSelection().toString()` via `do JavaScript`. This handles web page selections that the AX API may miss, especially in Safari where Accessibility text selection support is incomplete.

**Layer 4 — Menu action copy.** If Layers 2–3 fail, traverse the AX tree to find Edit → Copy and perform `AXPress`. This achieves clipboard-based capture without keystroke simulation side effects. Read the clipboard after a brief polling loop on `changeCount`.

**Layer 5 — Simulated ⌘C (last resort).** Mute the Alert sound volume, post CGEvent keyboard events for ⌘C, poll `changeCount`, read clipboard, restore Alert volume. Use `org.nspasteboard.TransientType` marking. Restore the original clipboard after a short delay.

**For text replacement across all layers:** If AX write fails, use clipboard-based paste — save clipboard, write translated text with `TransientType` marking, simulate ⌘V, restore clipboard after 100–200ms.

**Permissions required:** Accessibility (mandatory), Input Monitoring (if using global hotkey via event tap), Automation (if using AppleScript for browsers). Distribute outside the Mac App Store via Developer ID + notarization. Register a macOS Service as a bonus channel for native Cocoa apps — this provides the cleanest replacement path (private pasteboard, no clipboard pollution) for the ~60% of apps that support Services.

### Key open-source references for implementation

- **SelectedTextKit** (github.com/tisfeng/SelectedTextKit) — Complete 5-strategy text capture library in Swift
- **KeySender** (github.com/tisfeng/KeySender) — CGEvent keyboard simulation with Alert sound management
- **AXSwift** (github.com/tmandry/AXSwift) — Type-safe Swift wrapper for AXUIElement
- **AXorcist** (github.com/steipete/AXorcist) — Modern Swift AX wrapper with async/await (macOS 14+)
- **selection-hook** (github.com/0xfullex/selection-hook) — Node/Electron module combining event taps + AX + clipboard
- **Maccy** (github.com/p0deje/Maccy) — Reference implementation for clipboard monitoring and `changeCount` polling
- **Hammerspoon** hs.axuielement — Battle-tested Lua bindings with extensive app compatibility notes

## Conclusion

No single API solves macOS text capture universally. The Accessibility API covers ~70% of apps cleanly, AppleScript handles browsers, and clipboard-based fallbacks catch the rest. The recently discovered menu-action copy technique represents the most meaningful innovation in this space in years, eliminating the UX problems that previously made the clipboard fallback feel unpolished. The key architectural insight from production apps is that **strategy selection should be app-aware** — maintaining a bundle-ID-to-strategy mapping, rather than trying each strategy blindly, delivers the fastest and most reliable results. The entire pipeline requires non-sandboxed distribution, Accessibility permission, and careful clipboard management with `TransientType` signaling. Easydict's SelectedTextKit is the best starting point for implementation, providing a proven, open-source reference for the complete cascade.