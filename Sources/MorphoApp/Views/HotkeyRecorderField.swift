import AppKit
import MorphoKit
import SwiftUI

struct HotkeyRecorderField: NSViewRepresentable {
    let shortcut: HotkeyShortcut
    let onShortcutChange: (HotkeyShortcut) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onShortcutChange: onShortcutChange)
    }

    func makeNSView(context: Context) -> HotkeyRecorderTextField {
        let textField = HotkeyRecorderTextField()
        textField.placeholderString = "点击后按下组合键"
        textField.alignment = .center
        textField.isEditable = false
        textField.isSelectable = false
        textField.isBordered = true
        textField.drawsBackground = true
        textField.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        textField.focusRingType = .default
        textField.onShortcutCaptured = context.coordinator.handleShortcut
        textField.stringValue = HotkeyShortcutPresentation.summary(for: shortcut)
        return textField
    }

    func updateNSView(_ nsView: HotkeyRecorderTextField, context: Context) {
        nsView.onShortcutCaptured = context.coordinator.handleShortcut
        nsView.stringValue = HotkeyShortcutPresentation.summary(for: shortcut)
    }

    final class Coordinator {
        private let onShortcutChange: (HotkeyShortcut) -> Void

        init(onShortcutChange: @escaping (HotkeyShortcut) -> Void) {
            self.onShortcutChange = onShortcutChange
        }

        func handleShortcut(_ shortcut: HotkeyShortcut) {
            onShortcutChange(shortcut)
        }
    }
}

final class HotkeyRecorderTextField: NSTextField {
    var onShortcutCaptured: ((HotkeyShortcut) -> Void)?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard let shortcut = HotkeyRecorderShortcutBuilder.build(from: event) else {
            NSSound.beep()
            return
        }

        stringValue = HotkeyShortcutPresentation.summary(for: shortcut)
        onShortcutCaptured?(shortcut)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard let shortcut = HotkeyRecorderShortcutBuilder.build(from: event) else {
            return false
        }

        stringValue = HotkeyShortcutPresentation.summary(for: shortcut)
        onShortcutCaptured?(shortcut)
        return true
    }
}
