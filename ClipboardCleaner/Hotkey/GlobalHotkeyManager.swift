import AppKit
import Carbon
import Foundation

/// System-wide shortcut registration via Carbon's `RegisterEventHotKey`.
///
/// This is the native macOS mechanism for global hotkeys: no polling, no
/// Accessibility permission, and registration fails immediately when the
/// shortcut is already taken (spec §25).
@MainActor
final class GlobalHotkeyManager {

    enum RegistrationError: Error, Equatable {
        /// Another app (or this one) already owns that shortcut.
        case conflict
        /// The OS refused registration for another reason.
        case osStatus(OSStatus)

        var isConflict: Bool { self == .conflict }
    }

    /// 'CLNR' — identifies our hotkey among all registered hotkeys.
    private static let signature: OSType = 0x434C4E52
    private static let hotKeyNumber: UInt32 = 1

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    /// Invoked on the main actor when the shortcut fires.
    var onPressed: (() -> Void)?

    /// Temporarily ignore presses (used while recording a new shortcut).
    var isActive = true

    init() {
        installEventHandler()
    }

    // MARK: - Registration

    func register(_ shortcut: HotkeyShortcut) throws {
        unregister()

        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: Self.hotKeyNumber)
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &ref
        )

        guard status == noErr, let ref else {
            if status == OSStatus(eventHotKeyExistsErr) {
                throw RegistrationError.conflict
            }
            throw RegistrationError.osStatus(status)
        }
        hotKeyRef = ref
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
    }

    var isRegistered: Bool { hotKeyRef != nil }

    // MARK: - Event handling

    private func installEventHandler() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        // InstallApplicationEventHandler is a C macro; call its expansion.
        InstallEventHandler(
            GetApplicationEventTarget(),
            Self.hotKeyPressedCallback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
    }

    /// Carbon delivers hotkey events on the main run loop.
    /// `EventRef` is not Sendable, so the event is inspected here and
    /// only plain values cross into the main-actor closure.
    private static let hotKeyPressedCallback: @convention(c) (
        EventHandlerCallRef?,
        EventRef?,
        UnsafeMutableRawPointer?
    ) -> OSStatus = { _, event, userData in
        guard let userData else { return noErr }

        if let event {
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            if status == noErr, hotKeyID.signature != signature {
                return noErr
            }
        }

        let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(userData)
            .takeUnretainedValue()
        MainActor.assumeIsolated {
            manager.handleKeyPressed()
        }
        return noErr
    }

    private func handleKeyPressed() {
        guard isActive else { return }
        onPressed?()
    }
}
