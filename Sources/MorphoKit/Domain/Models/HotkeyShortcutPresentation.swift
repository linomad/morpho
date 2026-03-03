import Foundation

public enum HotkeyShortcutPresentation {
    private static let modifierKeyCodes: Set<UInt32> = [54, 55, 56, 58, 59, 60, 61, 62]

    private static let keyLabels: [UInt32: String] = [
        0: "A", 11: "B", 8: "C", 2: "D", 14: "E", 3: "F", 5: "G",
        4: "H", 34: "I", 38: "J", 40: "K", 37: "L", 46: "M", 45: "N",
        31: "O", 35: "P", 12: "Q", 15: "R", 1: "S", 17: "T", 32: "U",
        9: "V", 13: "W", 7: "X", 16: "Y", 6: "Z",
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5",
        22: "6", 26: "7", 28: "8", 25: "9", 29: "0",
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑",
    ]

    public static func summary(for shortcut: HotkeyShortcut) -> String {
        var parts: [String] = []
        if shortcut.modifiers.contains(.command) { parts.append("⌘") }
        if shortcut.modifiers.contains(.option) { parts.append("⌥") }
        if shortcut.modifiers.contains(.control) { parts.append("⌃") }
        if shortcut.modifiers.contains(.shift) { parts.append("⇧") }
        parts.append(keyLabel(for: shortcut.keyCode))
        return parts.joined()
    }

    public static func build(
        keyCode: UInt32,
        modifiers: HotkeyModifiers
    ) -> HotkeyShortcut? {
        guard modifiers.rawValue != 0 else {
            return nil
        }

        guard !modifierKeyCodes.contains(keyCode) else {
            return nil
        }

        return HotkeyShortcut(keyCode: keyCode, modifiers: modifiers)
    }

    public static func keyLabel(for keyCode: UInt32) -> String {
        keyLabels[keyCode] ?? "KeyCode(\(keyCode))"
    }
}
