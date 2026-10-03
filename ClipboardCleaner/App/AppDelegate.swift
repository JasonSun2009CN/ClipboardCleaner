import AppKit

/// Menu bar apps must not show a Dock icon or open any window at launch.
/// All this delegate does is guarantee the accessory activation policy
/// even if LSUIElement is ever dropped from the build settings.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
