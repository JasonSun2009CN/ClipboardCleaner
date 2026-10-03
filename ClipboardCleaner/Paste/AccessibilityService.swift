import AppKit
import ApplicationServices
import Foundation

/// The permission gate for synthetic ⌘V keystrokes (spec §26–28).
protocol AccessibilityChecking {
    var isTrusted: Bool { get }
    func openSystemSettings()
}

struct AccessibilityService: AccessibilityChecking {
    /// Whether this app may post keystrokes to other apps.
    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Opens System Settings → Privacy & Security → Accessibility.
    func openSystemSettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
