import AppKit
import Foundation
import Testing
@testable import ClipboardCleaner

/// Runs against a private named pasteboard — never the system clipboard.
@Suite("ClipboardWriter")
struct ClipboardWriterTests {
    private let pasteboard = NSPasteboard(name: NSPasteboard.Name("cc.writer.tests.\(UUID().uuidString)"))
    private var writer: ClipboardWriter { ClipboardWriter(pasteboard: pasteboard) }

    private func writeOriginal(html: String?, plain: String) {
        let item = NSPasteboardItem()
        item.setString(plain, forType: .string)
        if let html {
            item.setString(html, forType: .html)
        }
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
    }

    @Test("Capture, overwrite, restore round-trip")
    func roundTrip() {
        writeOriginal(html: "<b>Old</b>", plain: "Old")
        let point = writer.captureRestorePoint()

        let changeCount = writer.writeForPaste("Cleaned")
        #expect(changeCount != nil)
        #expect(pasteboard.string(forType: .string) == "Cleaned")

        let restored = writer.restore(point, expectingChangeCount: changeCount ?? -1)
        #expect(restored)
        #expect(pasteboard.string(forType: .string) == "Old")
        #expect(pasteboard.string(forType: .html) == "<b>Old</b>")
    }

    @Test("Restoration refuses to clobber a newer copy")
    func refusesNewerCopy() {
        writeOriginal(html: nil, plain: "Original")
        let point = writer.captureRestorePoint()
        let staleChangeCount = writer.writeForPaste("Cleaned")

        // Someone copies something new after our write.
        let newer = NSPasteboardItem()
        newer.setString("Newer", forType: .string)
        pasteboard.clearContents()
        pasteboard.writeObjects([newer])

        let restored = writer.restore(point, expectingChangeCount: staleChangeCount ?? -1)
        #expect(!restored)
        #expect(pasteboard.string(forType: .string) == "Newer")
    }

    @Test("Empty clipboard restores to empty")
    func emptyRestore() {
        pasteboard.clearContents()
        let point = writer.captureRestorePoint()
        #expect(point.items.isEmpty)

        let changeCount = writer.writeForPaste("Cleaned")
        #expect(writer.restore(point, expectingChangeCount: changeCount ?? -1))
        #expect(pasteboard.pasteboardItems?.isEmpty ?? true)
        #expect(pasteboard.string(forType: .string) == nil)
    }

    @Test("Multi-item pasteboards restore item by item")
    func multiItemRestore() {
        let first = NSPasteboardItem()
        first.setString("one", forType: .string)
        let second = NSPasteboardItem()
        second.setString("two", forType: .string)
        pasteboard.clearContents()
        pasteboard.writeObjects([first, second])

        let point = writer.captureRestorePoint()
        #expect(point.items.count == 2)

        let changeCount = writer.writeForPaste("merged")
        #expect(pasteboard.pasteboardItems?.count == 1)

        #expect(writer.restore(point, expectingChangeCount: changeCount ?? -1))
        #expect(pasteboard.pasteboardItems?.count == 2)
        #expect(pasteboard.pasteboardItems?.first?.string(forType: .string) == "one")
        #expect(pasteboard.pasteboardItems?.last?.string(forType: .string) == "two")
    }

    @Test("Each write bumps the changeCount")
    func changeCountMonotonic() {
        pasteboard.clearContents()
        let before = pasteboard.changeCount
        let after = writer.writeForPaste("x")
        #expect((after ?? -1) > before)
    }
}
