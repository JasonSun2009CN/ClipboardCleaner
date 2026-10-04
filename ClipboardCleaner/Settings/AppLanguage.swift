import Foundation

/// Interface language selectable in Settings (spec: language setting).
///
/// macOS resolves an app's interface language from the per-app
/// `AppleLanguages` default **at launch**, so changing the language
/// writes that default and the app relaunches to pick it up.
enum AppLanguage: String, CaseIterable, Sendable {
    /// No override — follow the system language (default).
    case system = "system"
    case english = "en"
    case chinese = "zh-Hans"

    var displayName: String {
        switch self {
        case .system: String(localized: "System Default")
        // Language names are shown in their own language, never translated.
        case .english: "English"
        case .chinese: "简体中文"
        }
    }

    /// The value for the `AppleLanguages` default, or `nil` when the
    /// app should follow the system language.
    var appleLanguageCode: String? {
        self == .system ? nil : rawValue
    }
}
