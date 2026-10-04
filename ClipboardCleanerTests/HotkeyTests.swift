import AppKit
import Carbon.HIToolbox
import Foundation
import Testing
@testable import ClipboardCleaner

@Suite("HotkeyShortcut")
struct HotkeyShortcutTests {
    @Test("Default shortcut from preferences displays as ⌘K")
    func defaultDisplay() {
        let prefs = AppPreferences(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let shortcut = HotkeyShortcut(preferences: prefs)
        #expect(shortcut.displayString == "⌘K")
        #expect(shortcut.hasModifier)
    }

    @Test("Carbon modifier mask matches the Carbon constants")
    func carbonMask() {
        let shortcut = HotkeyShortcut(
            keyCode: UInt32(kVK_ANSI_V),
            modifiers: [.option, .command]
        )
        let expected = UInt32(optionKey) | UInt32(cmdKey)
        #expect(shortcut.carbonModifiers == expected)
    }

    @Test("All four modifiers map and display in macOS order")
    func allModifiers() {
        let shortcut = HotkeyShortcut(
            keyCode: UInt32(kVK_ANSI_A),
            modifiers: [.command, .shift, .option, .control]
        )
        #expect(shortcut.displayString == "⌃⌥⇧⌘A")
        let expected = UInt32(controlKey) | UInt32(optionKey) | UInt32(shiftKey) | UInt32(cmdKey)
        #expect(shortcut.carbonModifiers == expected)
    }

    @Test("A bare key has no modifier")
    func bareKey() {
        let shortcut = HotkeyShortcut(keyCode: UInt32(kVK_ANSI_V), modifiers: [])
        #expect(!shortcut.hasModifier)
        #expect(shortcut.displayString == "V")
    }

    @Test("Special keys render their symbols")
    func specialKeys() {
        #expect(HotkeyShortcut(keyCode: UInt32(kVK_Space), modifiers: [.command]).displayString == "⌘Space")
        #expect(HotkeyShortcut(keyCode: UInt32(kVK_F5), modifiers: [.command]).displayString == "⌘F5")
        #expect(HotkeyShortcut(keyCode: UInt32(kVK_Return), modifiers: [.control]).displayString == "⌃↩")
    }

    @Test("Round-trips through preferences")
    func preferenceRoundTrip() {
        let prefs = AppPreferences(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let shortcut = HotkeyShortcut(keyCode: UInt32(kVK_ANSI_K), modifiers: [.control, .shift])
        shortcut.save(to: prefs)
        let loaded = HotkeyShortcut(preferences: prefs)
        #expect(loaded == shortcut)
    }
}

@Suite("GlobalHotkeyManager")
@MainActor
struct GlobalHotkeyManagerTests {
    /// An obscure combo no running app should own.
    private var testShortcut: HotkeyShortcut {
        HotkeyShortcut(
            keyCode: UInt32(kVK_F17),
            modifiers: [.control, .option, .shift]
        )
    }

    @Test("Register and unregister cleanly")
    func registerUnregister() throws {
        let manager = GlobalHotkeyManager()
        try manager.register(testShortcut)
        #expect(manager.isRegistered)
        manager.unregister()
        #expect(!manager.isRegistered)
    }

    @Test("Re-registration after change works")
    func reregister() throws {
        let manager = GlobalHotkeyManager()
        try manager.register(testShortcut)
        try manager.register(testShortcut) // internal unregister first
        #expect(manager.isRegistered)
        manager.unregister()
    }
}
