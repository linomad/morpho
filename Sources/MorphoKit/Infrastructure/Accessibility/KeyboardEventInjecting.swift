import ApplicationServices
import Foundation

enum KeyboardShortcut {
    case selectAll
    case copy
    case paste
}

protocol KeyboardEventInjecting {
    func trigger(_ shortcut: KeyboardShortcut) throws
}

enum KeyboardEventInjectionError: Error {
    case unableToCreateEvent
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
