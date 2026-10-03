import AppKit
import Foundation

/// All persisted user preferences. Thin UserDefaults wrapper — no Combine,
/// no notification bus. Views observe the owning `AppState` instead.
final class AppPreferences {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private enum Key {
        static let cleaningMode = "cleaningMode"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let permissionPromptShown = "permissionPromptShown"
    }

    /// Default paste shortcut: ⌥⌘V.
    static let defaultKeyCode: Int = 0x09 // kVK_ANSI_V
    static let defaultModifiers: UInt = NSEvent.ModifierFlags([.option, .command]).rawValue

    var cleaningMode: CleaningMode {
        get {
            defaults.string(forKey: Key.cleaningMode)
                .flatMap(CleaningMode.init(rawValue:)) ?? .plainText
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.cleaningMode)
        }
    }

    var hotkeyKeyCode: Int {
        get {
            let stored = defaults.object(forKey: Key.hotkeyKeyCode) as? Int
            return stored ?? Self.defaultKeyCode
        }
        set {
            defaults.set(newValue, forKey: Key.hotkeyKeyCode)
        }
    }

    var hotkeyModifiers: UInt {
        get {
            let stored = defaults.object(forKey: Key.hotkeyModifiers) as? UInt
            return stored ?? Self.defaultModifiers
        }
        set {
            defaults.set(newValue, forKey: Key.hotkeyModifiers)
        }
    }

    /// Whether the one-time Accessibility explanation dialog has been shown.
    var permissionPromptShown: Bool {
        get { defaults.bool(forKey: Key.permissionPromptShown) }
        set { defaults.set(newValue, forKey: Key.permissionPromptShown) }
    }
}
