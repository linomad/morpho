import Foundation

struct HotkeyKeyOption: Identifiable {
    let id: UInt32
    let label: String

    init(keyCode: UInt32, label: String) {
        self.id = keyCode
        self.label = label
    }
}

enum HotkeyKeyOptions {
    static let all: [HotkeyKeyOption] = [
        HotkeyKeyOption(keyCode: 0, label: "A"),
        HotkeyKeyOption(keyCode: 11, label: "B"),
        HotkeyKeyOption(keyCode: 8, label: "C"),
        HotkeyKeyOption(keyCode: 2, label: "D"),
        HotkeyKeyOption(keyCode: 14, label: "E"),
        HotkeyKeyOption(keyCode: 3, label: "F"),
        HotkeyKeyOption(keyCode: 5, label: "G"),
        HotkeyKeyOption(keyCode: 4, label: "H"),
        HotkeyKeyOption(keyCode: 34, label: "I"),
        HotkeyKeyOption(keyCode: 38, label: "J"),
        HotkeyKeyOption(keyCode: 40, label: "K"),
        HotkeyKeyOption(keyCode: 37, label: "L"),
        HotkeyKeyOption(keyCode: 46, label: "M"),
        HotkeyKeyOption(keyCode: 45, label: "N"),
        HotkeyKeyOption(keyCode: 31, label: "O"),
        HotkeyKeyOption(keyCode: 35, label: "P"),
        HotkeyKeyOption(keyCode: 12, label: "Q"),
        HotkeyKeyOption(keyCode: 15, label: "R"),
        HotkeyKeyOption(keyCode: 1, label: "S"),
        HotkeyKeyOption(keyCode: 17, label: "T"),
        HotkeyKeyOption(keyCode: 32, label: "U"),
        HotkeyKeyOption(keyCode: 9, label: "V"),
        HotkeyKeyOption(keyCode: 13, label: "W"),
        HotkeyKeyOption(keyCode: 7, label: "X"),
        HotkeyKeyOption(keyCode: 16, label: "Y"),
        HotkeyKeyOption(keyCode: 6, label: "Z")
    ]

    static func label(for keyCode: UInt32) -> String {
        all.first(where: { $0.id == keyCode })?.label ?? "KeyCode(\(keyCode))"
    }
}
