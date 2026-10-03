import AppKit
import Observation
import SwiftUI

/// Single source of truth for UI-visible app state.
/// Everything runs on the main actor; the cleaning engine itself is pure.
@MainActor
@Observable
final class AppState {
    let preferences: AppPreferences
    private(set) var registeredShortcut: HotkeyShortcut

    private let accessibility = AccessibilityService()
    private let pasteService: PasteService
    private let hotkey = GlobalHotkeyManager()
    private let feedbackWindow = FeedbackWindowController()
    private var flashTask: Task<Void, Never>?

    /// Transient HUD message; empty when nothing is shown.
    var feedbackMessage = ""

    /// The menu bar icon shows a warning while true (spec §28 feedback).
    var isFlashingPermission = false

    /// The current shortcut could not be registered (taken elsewhere).
    var isShortcutConflicted = false

    /// Is recorded keystroke capture active in Settings?
    var isRecordingShortcut = false

    init() {
        let prefs = AppPreferences()
        let service = PasteService(
            modeProvider: { prefs.cleaningMode },
            permissionPromptShown: { prefs.permissionPromptShown }
        )
        self.preferences = prefs
        self.registeredShortcut = HotkeyShortcut(preferences: prefs)
        self.pasteService = service

        service.onOutcome = { [weak self] outcome in
            self?.handle(outcome)
        }
        hotkey.onPressed = { [weak self] in
            self?.pasteClean()
        }

        do {
            try hotkey.register(registeredShortcut)
            isShortcutConflicted = false
        } catch {
            isShortcutConflicted = true
        }
    }

    // MARK: - Derived state

    var cleaningMode: CleaningMode {
        get { preferences.cleaningMode }
        set { preferences.cleaningMode = newValue }
    }

    var shortcut: HotkeyShortcut { registeredShortcut }

    var isAccessibilityTrusted: Bool { accessibility.isTrusted }

    // MARK: - Actions

    func pasteClean() {
        pasteService.trigger()
    }

    /// Re-registers the global shortcut. On failure the previous working
    /// shortcut is restored and `isShortcutConflicted` becomes true.
    func updateShortcut(_ new: HotkeyShortcut) {
        do {
            try hotkey.register(new)
            registeredShortcut = new
            new.save(to: preferences)
            isShortcutConflicted = false
        } catch {
            try? hotkey.register(registeredShortcut)
            isShortcutConflicted = true
        }
    }

    /// Pauses the global shortcut while a new one is being recorded.
    func setHotkeyPaused(_ paused: Bool) {
        hotkey.isActive = !paused
    }

    func openAccessibilitySettings() {
        accessibility.openSystemSettings()
    }

    func showFeedback(_ message: String) {
        feedbackMessage = message
        feedbackWindow.show(message)
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Outcome handling

    private func handle(_ outcome: PasteOutcome) {
        switch outcome {
        case .success:
            break // Invisible by default (spec §1.4).
        case .nothingToClean:
            showFeedback(String(localized: "Nothing to clean."))
        case .unsupportedContent:
            showFeedback(String(localized: "Clipboard contains unsupported content."))
        case .clipboardWriteFailed, .pasteFailed:
            showFeedback(String(localized: "Paste failed. Your clipboard was restored."))
        case .permissionRequired(let firstRequest):
            if firstRequest {
                showPermissionDialog()
            } else {
                // Never pop the dialog again (spec §28): menu bar status
                // plus a brief icon flash is all the feedback given.
                flashPermissionIcon()
            }
        }
    }

    /// Shown exactly once, the first time Paste Clean needs permission.
    private func showPermissionDialog() {
        preferences.permissionPromptShown = true

        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = String(localized: "Clipboard Cleaner needs permission")
        alert.informativeText = String(localized: """
        Clipboard Cleaner needs Accessibility permission to paste \
        cleaned text into other apps.
        """)
        alert.addButton(withTitle: String(localized: "Open Settings"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        alert.alertStyle = .informational

        if alert.runModal() == .alertFirstButtonReturn {
            accessibility.openSystemSettings()
        }
    }

    private func flashPermissionIcon() {
        isFlashingPermission = true
        flashTask?.cancel()
        flashTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            self?.isFlashingPermission = false
        }
    }
}
