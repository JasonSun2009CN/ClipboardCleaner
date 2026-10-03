import Foundation
import Testing
@testable import ClipboardCleaner

@Suite("CleaningMode")
struct CleaningModeTests {
    @Test("Defaults to plain text")
    func defaultMode() {
        let prefs = AppPreferences(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        #expect(prefs.cleaningMode == .plainText)
    }

    @Test("Round-trips through UserDefaults")
    func roundTrip() {
        let prefs = AppPreferences(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        prefs.cleaningMode = .normalize
        #expect(prefs.cleaningMode == .normalize)
    }

    @Test("Default shortcut is ⌥⌘V")
    func defaultShortcut() {
        let prefs = AppPreferences(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        #expect(prefs.hotkeyKeyCode == AppPreferences.defaultKeyCode)
        #expect(prefs.hotkeyModifiers == AppPreferences.defaultModifiers)
    }
}
