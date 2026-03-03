import AppKit
import MorphoKit

enum HotkeyRecorderShortcutBuilder {
    static func build(from event: NSEvent) -> HotkeyShortcut? {
        var modifiers: HotkeyModifiers = []

        if event.modifierFlags.contains(.command) {
            modifiers.insert(.command)
        }
        if event.modifierFlags.contains(.option) {
            modifiers.insert(.option)
        }
        if event.modifierFlags.contains(.control) {
            modifiers.insert(.control)
        }
        if event.modifierFlags.contains(.shift) {
            modifiers.insert(.shift)
        }

        return HotkeyShortcutPresentation.build(
            keyCode: UInt32(event.keyCode),
            modifiers: modifiers
        )
    }
}
