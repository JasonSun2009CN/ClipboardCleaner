import AppKit
import Carbon
import Foundation
import OSLog

/// What happened when Paste Clean was triggered.
enum PasteOutcome: Equatable {
    case success
    case nothingToClean
    case unsupportedContent
    /// Accessibility permission is missing. `firstRequest` is true only
    /// the very first time — afterwards we never pop a dialog again.
    case permissionRequired(firstRequest: Bool)
    /// Synthetic ⌘V could not be posted; the clipboard was restored.
    case pasteFailed
    /// The cleaned text could not be written back to the clipboard.
    case clipboardWriteFailed
}

/// The full Paste Clean pipeline (spec §21):
/// read → clean → write → ⌘V → restore. Everything happens on demand at
/// the moment the user presses the shortcut — no clipboard monitoring.
@MainActor
final class PasteService {

    private let reader: ClipboardReader
    private let writer: ClipboardWriter
    private let accessibility: AccessibilityChecking
    private let modeProvider: () -> CleaningMode
    private let injectPaste: () -> Bool
    private let permissionPromptShown: () -> Bool
    private let restoreDelay: TimeInterval
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "ClipboardCleaner", category: "paste")

    /// Reported back to AppState for user feedback.
    var onOutcome: ((PasteOutcome) -> Void)?

    private var isRunning = false
    private var restoreTask: Task<Void, Never>?

    /// HTML/plain payloads above this size are cleaned off the main
    /// thread so a pathological clipboard never blocks the UI (spec §40).
    private static let backgroundThreshold = 512 * 1024

    init(
        pasteboard: NSPasteboard = .general,
        accessibility: AccessibilityChecking = AccessibilityService(),
        restoreDelay: TimeInterval = 0.35,
        modeProvider: @escaping () -> CleaningMode,
        permissionPromptShown: @escaping () -> Bool = { true },
        injectPaste: @escaping () -> Bool = PasteService.postPasteKeystroke
    ) {
        reader = ClipboardReader(pasteboard: pasteboard)
        writer = ClipboardWriter(pasteboard: pasteboard)
        self.accessibility = accessibility
        self.modeProvider = modeProvider
        self.permissionPromptShown = permissionPromptShown
        self.injectPaste = injectPaste
        self.restoreDelay = restoreDelay
    }

    // MARK: - Trigger

    func trigger() {
        // Ignore re-entrant triggers while a paste/restore cycle runs.
        guard !isRunning else { return }

        guard accessibility.isTrusted else {
            onOutcome?(.permissionRequired(firstRequest: !permissionPromptShown()))
            return
        }

        switch reader.read() {
        case .empty:
            onOutcome?(.nothingToClean)
        case .unsupported:
            onOutcome?(.unsupportedContent)
        case .text(let snapshot):
            cleanAndPaste(snapshot)
        }
    }

    private func cleanAndPaste(_ snapshot: ClipboardSnapshot) {
        isRunning = true

        let restorePoint = writer.captureRestorePoint()
        let mode = modeProvider()
        let payloadSize = (snapshot.html?.count ?? 0) + (snapshot.plainText?.count ?? 0)

        if payloadSize > Self.backgroundThreshold {
            Task.detached(priority: .userInitiated) { [weak self] in
                let cleaned = CleaningEngine.clean(snapshot, mode: mode)
                await self?.continueWithCleaned(cleaned, restorePoint: restorePoint)
            }
        } else {
            let cleaned = CleaningEngine.clean(snapshot, mode: mode)
            continueWithCleaned(cleaned, restorePoint: restorePoint)
        }
    }

    private func continueWithCleaned(_ cleaned: String?, restorePoint: PasteboardRestorePoint) {
        guard let cleaned, !cleaned.isEmpty else {
            isRunning = false
            onOutcome?(.nothingToClean)
            return
        }

        guard let changeCount = writer.writeForPaste(cleaned, fallback: restorePoint) else {
            logger.error("Clean paste failed: could not write cleaned text")
            isRunning = false
            onOutcome?(.clipboardWriteFailed)
            return
        }

        guard injectPaste() else {
            // Paste never happened — restore right away (spec §23).
            _ = writer.restore(restorePoint, expectingChangeCount: changeCount)
            logger.error("Clean paste failed: could not post keystroke")
            isRunning = false
            onOutcome?(.pasteFailed)
            return
        }

        scheduleRestoration(restorePoint, changeCount: changeCount)
    }

    // MARK: - Restoration

    private func scheduleRestoration(_ point: PasteboardRestorePoint, changeCount: Int) {
        restoreTask?.cancel()
        restoreTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(self.restoreDelay))
            guard !Task.isCancelled else { return }

            let restored = self.writer.restore(point, expectingChangeCount: changeCount)
            self.isRunning = false
            if restored {
                self.logger.info("Clean paste completed")
                self.onOutcome?(.success)
            } else {
                // Another copy happened during the paste window; the newer
                // content wins. Nothing else to restore.
                self.logger.info("Clipboard restoration skipped: clipboard changed externally")
                self.onOutcome?(.success)
            }
        }
    }

    // MARK: - Keystroke

    /// Posts ⌘V to the frontmost app. Requires Accessibility permission.
    nonisolated static func postPasteKeystroke() -> Bool {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCode = CGKeyCode(kVK_ANSI_V)

        guard
            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}
