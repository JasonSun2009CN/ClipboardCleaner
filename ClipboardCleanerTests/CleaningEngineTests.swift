import AppKit
import Foundation
import Testing
@testable import ClipboardCleaner

@Suite("CleaningEngine")
struct CleaningEngineTests {
    private func makeRTF(_ text: String) throws -> Data {
        let attributed = NSAttributedString(string: text)
        return try #require(
            try attributed.data(
                from: NSRange(location: 0, length: attributed.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
        )
    }

    // MARK: - Priority (spec §7)

    @Test("HTML wins over RTF and plain text")
    func htmlPriority() throws {
        let snapshot = ClipboardSnapshot(
            plainText: "plain",
            html: "<p>html</p>",
            rtf: try makeRTF("rtf")
        )
        #expect(CleaningEngine.clean(snapshot, mode: .plainText) == "html")
    }

    @Test("RTF wins over plain text when HTML is absent")
    func rtfPriority() throws {
        let snapshot = ClipboardSnapshot(
            plainText: "plain",
            html: nil,
            rtf: try makeRTF("rtf text")
        )
        #expect(CleaningEngine.clean(snapshot, mode: .plainText) == "rtf text")
    }

    @Test("Unusable HTML falls through to plain text")
    func htmlFallsThrough() {
        let snapshot = ClipboardSnapshot(
            plainText: "fallback",
            html: "<!-- comment only -->",
            rtf: nil
        )
        #expect(CleaningEngine.clean(snapshot, mode: .plainText) == "fallback")
    }

    @Test("Unparseable RTF falls through to plain text")
    func rtfFallsThrough() {
        let snapshot = ClipboardSnapshot(
            plainText: "fallback",
            html: nil,
            rtf: Data("not really rtf".utf8)
        )
        #expect(CleaningEngine.clean(snapshot, mode: .plainText) == "fallback")
    }

    @Test("Nothing to clean returns nil")
    func emptySnapshot() {
        #expect(CleaningEngine.clean(.empty, mode: .plainText) == nil)
        #expect(CleaningEngine.clean(.empty, mode: .normalize) == nil)
    }

    // MARK: - Modes (spec §17/18/19)

    @Test("Default mode preserves the user's spacing in plain text")
    func plainModePreserves() {
        let snapshot = ClipboardSnapshot(plainText: "Hello   World", html: nil, rtf: nil)
        #expect(CleaningEngine.clean(snapshot, mode: .plainText) == "Hello   World")
    }

    @Test("Normalize mode collapses spacing in plain text")
    func normalizeModeCollapses() {
        let snapshot = ClipboardSnapshot(plainText: "Hello   World", html: nil, rtf: nil)
        #expect(CleaningEngine.clean(snapshot, mode: .normalize) == "Hello World")
    }

    @Test("Plain mode normalizes line endings only")
    func plainModeLineEndings() {
        let snapshot = ClipboardSnapshot(plainText: "a  b\r\nc", html: nil, rtf: nil)
        #expect(CleaningEngine.clean(snapshot, mode: .plainText) == "a  b\nc")
    }

    @Test("HTML structure survives Normalize mode")
    func normalizeKeepsHtmlStructure() {
        let html = "<ul><li>Apple<ul><li>Red Apple</li></ul></li></ul>"
        let snapshot = ClipboardSnapshot(plainText: nil, html: html, rtf: nil)
        #expect(CleaningEngine.clean(snapshot, mode: .normalize) == "• Apple\n  • Red Apple")
    }

    @Test("RTF respects the selected mode")
    func rtfModes() throws {
        let snapshot = ClipboardSnapshot(
            plainText: nil,
            html: nil,
            rtf: try makeRTF("Hello   World")
        )
        #expect(CleaningEngine.clean(snapshot, mode: .plainText) == "Hello   World")
        #expect(CleaningEngine.clean(snapshot, mode: .normalize) == "Hello World")
    }
}
