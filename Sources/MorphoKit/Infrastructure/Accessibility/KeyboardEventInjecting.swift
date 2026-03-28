import ApplicationServices
import Foundation

enum KeyboardShortcut {
    case selectAll
    case copy
    case paste
}

protocol KeyboardEventInjecting {
    func trigger(_ shortcut: KeyboardShortcut) throws
    func insertText(_ text: String) throws
}

enum KeyboardEventInjectionError: Error {
    case unableToCreateEvent
}

extension KeyboardEventInjecting {
    func insertText(_ text: String) throws {
        throw KeyboardEventInjectionError.unableToCreateEvent
    }
}

final class SystemKeyboardEventInjector: KeyboardEventInjecting {
    private enum KeyCode {
        static let a: CGKeyCode = 0
        static let c: CGKeyCode = 8
        static let v: CGKeyCode = 9
    }

    func trigger(_ shortcut: KeyboardShortcut) throws {
        let keyCode: CGKeyCode
        switch shortcut {
        case .selectAll:
            keyCode = KeyCode.a
        case .copy:
            keyCode = KeyCode.c
        case .paste:
            keyCode = KeyCode.v
        }

        try postCommandKey(keyCode: keyCode)
    }

    func insertText(_ text: String) throws {
        let utf16 = Array(text.utf16)
        guard
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)
        else {
            throw KeyboardEventInjectionError.unableToCreateEvent
        }

        keyDown.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        keyUp.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private func postCommandKey(keyCode: CGKeyCode) throws {
        guard
            let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        else {
            throw KeyboardEventInjectionError.unableToCreateEvent
        }

        keyDown.flags = [.maskCommand]
        keyUp.flags = [.maskCommand]
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
