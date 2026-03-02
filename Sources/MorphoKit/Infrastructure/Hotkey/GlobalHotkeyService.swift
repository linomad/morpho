import Carbon
import Foundation

public enum HotkeyRegistrationError: Error {
    case installHandlerFailed(OSStatus)
    case registerFailed(OSStatus)
}

public final class GlobalHotkeyService {
    public var onHotkeyPressed: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private let hotKeySignature = OSType(0x4D525048) // MRPH
    private let hotKeyIdentifier: UInt32 = 1

    public init() throws {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else {
                return noErr
            }

            let instance = Unmanaged<GlobalHotkeyService>.fromOpaque(userData).takeUnretainedValue()
            return instance.handleHotkey(event)
        }

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )

        guard installStatus == noErr else {
            throw HotkeyRegistrationError.installHandlerFailed(installStatus)
        }
    }

    deinit {
        unregister()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    public func register(_ shortcut: HotkeyShortcut) throws {
        unregister()

        let hotKeyID = EventHotKeyID(signature: hotKeySignature, id: hotKeyIdentifier)

        let registerStatus = RegisterEventHotKey(
            shortcut.keyCode,
            carbonModifiers(from: shortcut.modifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard registerStatus == noErr else {
            throw HotkeyRegistrationError.registerFailed(registerStatus)
        }
    }

    public func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func handleHotkey(_ event: EventRef) -> OSStatus {
        var incomingID = EventHotKeyID()

        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &incomingID
        )

        guard status == noErr else {
            return status
        }

        if incomingID.signature == hotKeySignature, incomingID.id == hotKeyIdentifier {
            onHotkeyPressed?()
        }

        return noErr
    }

    private func carbonModifiers(from modifiers: HotkeyModifiers) -> UInt32 {
        var result: UInt32 = 0

        if modifiers.contains(.command) {
            result |= UInt32(cmdKey)
        }
        if modifiers.contains(.option) {
            result |= UInt32(optionKey)
        }
        if modifiers.contains(.control) {
            result |= UInt32(controlKey)
        }
        if modifiers.contains(.shift) {
            result |= UInt32(shiftKey)
        }

        return result
    }
}
