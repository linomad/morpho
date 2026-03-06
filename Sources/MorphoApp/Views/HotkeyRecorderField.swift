import AppKit
import MorphoKit
import SwiftUI

struct HotkeyRecorderField: NSViewRepresentable {
    let shortcut: HotkeyShortcut
    let isEnabled: Bool
    let locale: Locale
    let onShortcutChange: (HotkeyShortcut) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onShortcutChange: onShortcutChange)
    }

    func makeNSView(context: Context) -> HotkeyRecorderTextField {
        let textField = HotkeyRecorderTextField()
        textField.onShortcutCaptured = context.coordinator.handleShortcut
        textField.shortcut = shortcut
        textField.isShortcutEnabled = isEnabled
        textField.locale = locale
        return textField
    }

    func updateNSView(_ nsView: HotkeyRecorderTextField, context: Context) {
        nsView.onShortcutCaptured = context.coordinator.handleShortcut
        nsView.shortcut = shortcut
        nsView.isShortcutEnabled = isEnabled
        nsView.locale = locale
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
    private enum Appearance {
        static let cornerRadius: CGFloat = 10
        static let normalBorderWidth: CGFloat = 1
        static let focusedBorderWidth: CGFloat = 1.5
        static let focusedShadowRadius: CGFloat = 3
    }

    var onShortcutCaptured: ((HotkeyShortcut) -> Void)?
    var locale: Locale = .autoupdatingCurrent {
        didSet {
            updateLocalizedCopy()
        }
    }

    var shortcut: HotkeyShortcut = .defaultValue {
        didSet {
            if !isRecording {
                stringValue = HotkeyShortcutPresentation.summary(for: shortcut)
            }
        }
    }

    var isShortcutEnabled = true {
        didSet {
            if !isShortcutEnabled {
                stopRecording(resignFirstResponder: true)
            }

            if !isRecording {
                stringValue = HotkeyShortcutPresentation.summary(for: shortcut)
            }
            updateVisualStyle()
        }
    }

    private var isRecording = false {
        didSet {
            stringValue = isRecording
                ? AppLocalization.string("hotkey.recorder.recording", locale: locale)
                : HotkeyShortcutPresentation.summary(for: shortcut)
            updateVisualStyle()
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureAppearance()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureAppearance()
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
    }

    override func resignFirstResponder() -> Bool {
        let didResign = super.resignFirstResponder()
        if didResign, isRecording {
            stopRecording(resignFirstResponder: false)
        }
        return didResign
    }

    override func mouseDown(with event: NSEvent) {
        guard isShortcutEnabled else {
            return
        }
        startRecording()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            return
        }

        if event.keyCode == 53 { // ESC
            stopRecording(resignFirstResponder: true)
            return
        }

        guard let shortcut = HotkeyRecorderShortcutBuilder.build(from: event) else {
            NSSound.beep()
            return
        }

        self.shortcut = shortcut
        onShortcutCaptured?(shortcut)
        stopRecording(resignFirstResponder: true)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else {
            return false
        }

        if event.keyCode == 53 { // ESC
            stopRecording(resignFirstResponder: true)
            return true
        }

        guard let shortcut = HotkeyRecorderShortcutBuilder.build(from: event) else {
            NSSound.beep()
            return true
        }

        self.shortcut = shortcut
        onShortcutCaptured?(shortcut)
        stopRecording(resignFirstResponder: true)
        return true
    }

    private func configureAppearance() {
        alignment = .center
        isEditable = false
        isSelectable = false
        isBordered = false
        drawsBackground = false
        font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
        textColor = .labelColor
        focusRingType = .none
        lineBreakMode = .byTruncatingTail
        maximumNumberOfLines = 1
        wantsLayer = true
        updateLocalizedCopy()
        stringValue = HotkeyShortcutPresentation.summary(for: shortcut)
        updateVisualStyle()
    }

    private func updateLocalizedCopy() {
        placeholderString = AppLocalization.string("hotkey.recorder.placeholder", locale: locale)
        toolTip = AppLocalization.string("hotkey.recorder.tooltip", locale: locale)
        if isRecording {
            stringValue = AppLocalization.string("hotkey.recorder.recording", locale: locale)
        }
    }

    private func updateVisualStyle() {
        guard let layer else { return }

        let borderColor: NSColor
        let backgroundColor: NSColor
        let textColor: NSColor

        if !isShortcutEnabled {
            borderColor = NSColor.separatorColor.withAlphaComponent(0.6)
            backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.45)
            textColor = NSColor.secondaryLabelColor
        } else if isRecording {
            borderColor = NSColor.controlAccentColor
            backgroundColor = NSColor.textBackgroundColor
            textColor = NSColor.labelColor
        } else {
            borderColor = NSColor.separatorColor.withAlphaComponent(0.9)
            backgroundColor = NSColor.textBackgroundColor
            textColor = NSColor.labelColor
        }

        self.textColor = textColor
        alphaValue = isShortcutEnabled ? 1 : 0.72
        layer.backgroundColor = backgroundColor.cgColor
        layer.cornerRadius = Appearance.cornerRadius
        layer.borderColor = borderColor.cgColor
        layer.borderWidth = isRecording ? Appearance.focusedBorderWidth : Appearance.normalBorderWidth
        layer.shadowColor = isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.22).cgColor : nil
        layer.shadowOpacity = isRecording ? 1 : 0
        layer.shadowRadius = isRecording ? Appearance.focusedShadowRadius : 0
        layer.shadowOffset = CGSize(width: 0, height: 1)
    }

    private func startRecording() {
        guard isShortcutEnabled else {
            return
        }

        if !isRecording {
            isRecording = true
        }
        window?.makeFirstResponder(self)
    }

    private func stopRecording(resignFirstResponder: Bool) {
        guard isRecording else {
            return
        }

        isRecording = false
        if resignFirstResponder, window?.firstResponder === self {
            window?.makeFirstResponder(nil)
        }
    }
}
