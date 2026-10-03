import AppKit
import Foundation
import Testing
@testable import ClipboardCleaner

@Suite("PasteService")
@MainActor
struct PasteServiceTests {
    private struct StubAccessibility: AccessibilityChecking {
        var isTrusted: Bool
        func openSystemSettings() {}
    }

    /// Mutable state shared with the injected closures. Deliberately not
    /// actor-isolated so the `() -> Bool` injection closure can touch it.
    private final class Recorder {
        var outcomes: [PasteOutcome] = []
        var injectCalls = 0
        var injectResult = true
        var promptShown = false
    }

    /// Harness wiring a PasteService to a private pasteboard with a
    /// recorded (never posted) keystroke.
    @MainActor
    private final class Harness {
        let recorder: Recorder
        let pasteboard: NSPasteboard
        let service: PasteService

        init(trusted: Bool = true, restoreDelay: TimeInterval = 0.02) {
            let rec = Recorder()
            let board = NSPasteboard(name: NSPasteboard.Name("cc.paste.tests.\(UUID().uuidString)"))

            let service = PasteService(
                pasteboard: board,
                accessibility: StubAccessibility(isTrusted: trusted),
                restoreDelay: restoreDelay,
                modeProvider: { .plainText },
                permissionPromptShown: { rec.promptShown },
                injectPaste: {
                    rec.injectCalls += 1
                    return rec.injectResult
                }
            )
            service.onOutcome = { outcome in
                rec.outcomes.append(outcome)
            }

            self.recorder = rec
            self.pasteboard = board
            self.service = service
        }

        func writeRich(html: String?, plain: String) {
            let item = NSPasteboardItem()
            item.setString(plain, forType: .string)
            if let html {
                item.setString(html, forType: .html)
            }
            pasteboard.clearContents()
            pasteboard.writeObjects([item])
        }
    }

    @Test("Success flow cleans, pastes, then restores the original")
    func successFlow() async throws {
        let harness = Harness()
        harness.writeRich(html: "<p><b>Rich</b></p>", plain: "Plain")

        harness.service.trigger()

        // HTML wins: the cleaned text is on the clipboard pre-restoration.
        #expect(harness.recorder.injectCalls == 1)
        #expect(harness.pasteboard.string(forType: .string) == "Rich")

        try await Task.sleep(for: .seconds(0.1))
        #expect(harness.recorder.outcomes == [.success])
        // Original flavours are back.
        #expect(harness.pasteboard.string(forType: .string) == "Plain")
        #expect(harness.pasteboard.string(forType: .html) == "<p><b>Rich</b></p>")
    }

    @Test("Cleaned text is on the clipboard during the paste window")
    func cleanedContentDuringWindow() async throws {
        let harness = Harness(restoreDelay: 0.15)
        harness.writeRich(html: "<p>Hello   World</p>", plain: "ignored")

        harness.service.trigger()

        // During the paste window the cleaned output must be present.
        #expect(harness.pasteboard.string(forType: .string) == "Hello World")

        try await Task.sleep(for: .seconds(0.3))
        #expect(harness.pasteboard.string(forType: .html) == "<p>Hello   World</p>")
    }

    @Test("Empty clipboard reports nothing to clean")
    func emptyClipboard() {
        let harness = Harness()
        harness.pasteboard.clearContents()

        harness.service.trigger()

        #expect(harness.recorder.outcomes == [.nothingToClean])
        #expect(harness.recorder.injectCalls == 0)
    }

    @Test("Copied file reports unsupported content")
    func unsupportedFile() throws {
        let harness = Harness()
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cc-paste-\(UUID().uuidString).txt")
        try Data("x".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        harness.pasteboard.clearContents()
        harness.pasteboard.writeObjects([fileURL as NSURL])

        harness.service.trigger()

        #expect(harness.recorder.outcomes == [.unsupportedContent])
        #expect(harness.recorder.injectCalls == 0)
    }

    @Test("First use without permission asks once, then stays silent")
    func permissionFlow() {
        let harness = Harness(trusted: false)

        harness.service.trigger()
        #expect(harness.recorder.outcomes == [.permissionRequired(firstRequest: true)])
        #expect(harness.recorder.injectCalls == 0)

        // The dialog has now been shown; later triggers never pop it again.
        harness.recorder.promptShown = true
        harness.service.trigger()
        #expect(harness.recorder.outcomes == [
            .permissionRequired(firstRequest: true),
            .permissionRequired(firstRequest: false),
        ])
        #expect(harness.recorder.injectCalls == 0)
    }

    @Test("Failed keystroke restores the clipboard immediately")
    func failedKeystrokeRestores() {
        let harness = Harness()
        harness.writeRich(html: nil, plain: "Original")
        harness.recorder.injectResult = false

        harness.service.trigger()

        #expect(harness.recorder.outcomes == [.pasteFailed])
        #expect(harness.recorder.injectCalls == 1)
        #expect(harness.pasteboard.string(forType: .string) == "Original")
    }

    @Test("HTML that reduces to nothing reports nothing to clean")
    func htmlWithoutContent() {
        let harness = Harness()
        let item = NSPasteboardItem()
        item.setString("<!-- only a comment -->", forType: .html)
        harness.pasteboard.clearContents()
        harness.pasteboard.writeObjects([item])

        harness.service.trigger()

        #expect(harness.recorder.outcomes == [.nothingToClean])
        #expect(harness.recorder.injectCalls == 0)
    }

    @Test("Triggers during an active cycle are ignored")
    func reentrancy() async throws {
        let harness = Harness(restoreDelay: 0.2)
        harness.writeRich(html: nil, plain: "text")

        harness.service.trigger()
        harness.service.trigger() // ignored: cycle still running
        #expect(harness.recorder.injectCalls == 1)

        try await Task.sleep(for: .seconds(0.35))
        #expect(harness.recorder.outcomes == [.success])
    }
}
