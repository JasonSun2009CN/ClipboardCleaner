import AppKit
import Observation

/// Single source of truth for UI-visible app state.
/// Everything runs on the main actor; the cleaning engine itself is pure.
@MainActor
@Observable
final class AppState {
    let preferences = AppPreferences()

    /// Transient user feedback ("Nothing to clean.", errors). Empty when none.
    var feedbackMessage: String?

    /// Set once the user dismisses the Accessibility dialog; after that we
    /// never pop it again — menu bar status only (per product spec).
    var permissionDialogShownOnce = false

    var cleaningMode: CleaningMode {
        get { preferences.cleaningMode }
        set { preferences.cleaningMode = newValue }
    }

    // MARK: - Actions

    func pasteClean() {
        // Slice 6 wires the full pipeline: permission → read → clean →
        // write → paste → restore.
    }

    func showFeedback(_ message: String) {
        feedbackMessage = message
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }
}
