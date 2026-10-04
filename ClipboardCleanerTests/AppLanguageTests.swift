import Foundation
import Testing
@testable import ClipboardCleaner

@Suite("AppLanguage")
struct AppLanguageTests {
    private let suiteName = UUID().uuidString

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: suiteName)!
    }

    @Test("Defaults to system language")
    func defaultLanguage() {
        let prefs = AppPreferences(defaults: makeDefaults())
        #expect(prefs.appLanguage == .system)
        #expect(prefs.appLanguage.appleLanguageCode == nil)
    }

    @Test("Round-trips through UserDefaults")
    func roundTrip() {
        let defaults = makeDefaults()
        let prefs = AppPreferences(defaults: defaults)
        prefs.appLanguage = .chinese
        #expect(AppPreferences(defaults: defaults).appLanguage == .chinese)
    }

    @Test("Selecting a language writes the AppleLanguages default")
    func writesAppleLanguages() {
        let defaults = makeDefaults()
        let prefs = AppPreferences(defaults: defaults)
        prefs.appLanguage = .english
        #expect(defaults.stringArray(forKey: AppPreferences.appleLanguagesKey) == ["en"])

        prefs.appLanguage = .chinese
        #expect(defaults.stringArray(forKey: AppPreferences.appleLanguagesKey) == ["zh-Hans"])
    }

    @Test("Selecting System Default removes the AppleLanguages override")
    func systemRemovesOverride() {
        let defaults = makeDefaults()
        let prefs = AppPreferences(defaults: defaults)
        prefs.appLanguage = .chinese
        // Assert on the suite's own domain: a plain read would fall back
        // to the global AppleLanguages (the actual system languages),
        // which is exactly the "follow system" behaviour in the app.
        _ = defaults.synchronize()
        #expect(defaults.persistentDomain(forName: suiteName)?[AppPreferences.appleLanguagesKey] != nil)

        prefs.appLanguage = .system
        _ = defaults.synchronize()
        #expect(defaults.persistentDomain(forName: suiteName)?[AppPreferences.appleLanguagesKey] == nil)
    }

    @Test("Display names: language names stay untranslated")
    func displayNames() {
        #expect(AppLanguage.english.displayName == "English")
        #expect(AppLanguage.chinese.displayName == "简体中文")
        #expect(!AppLanguage.system.displayName.isEmpty)
    }
}
