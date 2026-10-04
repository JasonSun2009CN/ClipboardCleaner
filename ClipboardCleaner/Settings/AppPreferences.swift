import AppKit
import Foundation
import Observation

/// All persisted user preferences. Thin UserDefaults wrapper — no Combine.
/// Views observe the owning `AppState` and reach these values through it.
@Observable
final class AppPreferences {
    private let defaults: UserDefaults

    private enum Key {
        static let cleaningMode = "cleaningMode"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let permissionPromptShown = "permissionPromptShown"
        static let appLanguage = "appLanguage"
    }

    /// Per-app interface-language override; `AppleLanguages` is how
    /// macOS selects the bundle's localization at launch.
    static let appleLanguagesKey = "AppleLanguages"

    /// Default paste shortcut: ⌘K.
    static let defaultKeyCode: Int = 0x28 // kVK_ANSI_K
    static let defaultModifiers: UInt = NSEvent.ModifierFlags([.command]).rawValue

    /// Stored rather than read from `defaults` on every access:
    /// `@Observable` only tracks stored properties, and SwiftUI views
    /// (menu bar panel, Settings picker) must re-render on mode change.
    var cleaningMode: CleaningMode {
        didSet { defaults.set(cleaningMode.rawValue, forKey: Key.cleaningMode) }
    }

    /// Interface language. Writing it also updates the per-app
    /// `AppleLanguages` default so the next launch uses that language.
    var appLanguage: AppLanguage {
        didSet {
            defaults.set(appLanguage.rawValue, forKey: Key.appLanguage)
            if let code = appLanguage.appleLanguageCode {
                defaults.set([code], forKey: Self.appleLanguagesKey)
            } else {
                defaults.removeObject(forKey: Self.appleLanguagesKey)
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.cleaningMode = defaults.string(forKey: Key.cleaningMode)
            .flatMap(CleaningMode.init(rawValue:)) ?? .plainText
        self.appLanguage = defaults.string(forKey: Key.appLanguage)
            .flatMap(AppLanguage.init(rawValue:)) ?? .system
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
