import AppKit
import Foundation
import Testing
@testable import ClipboardCleaner

/// Tests run against a private named pasteboard — the system clipboard
/// is never touched.
@Suite("ClipboardReader")
struct ClipboardReaderTests {
    private let pasteboard = NSPasteboard(name: NSPasteboard.Name("cc.tests.\(UUID().uuidString)"))

    private func makeReader() -> ClipboardReader {
        ClipboardReader(pasteboard: pasteboard)
    }

    private func write(_ items: [NSPasteboardWriting]) {
        pasteboard.clearContents()
        pasteboard.writeObjects(items)
    }

    private func item(_ flavors: [(NSPasteboard.PasteboardType, Any)]) -> NSPasteboardItem {
        let item = NSPasteboardItem()
        for (type, value) in flavors {
            switch value {
            case let data as Data:
                item.setData(data, forType: type)
            case let string as String:
                item.setString(string, forType: type)
            default:
                Issue.record("unsupported flavor value")
            }
        }
        return item
    }

    @Test("Empty pasteboard reads as empty")
    func emptyPasteboard() {
        pasteboard.clearContents()
        #expect(makeReader().read() == .empty)
    }

    @Test("Plain string only")
    func plainString() {
        write([item([(.string, "Hello")])])
        #expect(makeReader().read() == .text(ClipboardSnapshot(plainText: "Hello", html: nil, rtf: nil)))
    }

    @Test("HTML and plain text ride on the same item")
    func htmlAndString() {
        write([item([(.string, "Hello"), (.html, "<p>Hello</p>")])])
        let result = makeReader().read()
        #expect(result == .text(ClipboardSnapshot(plainText: "Hello", html: "<p>Hello</p>", rtf: nil)))
    }

    @Test("RTF is captured as raw data")
    func rtfCapture() throws {
        let attributed = NSAttributedString(string: "Rich")
        let rtf = try #require(
            try attributed.data(
                from: NSRange(location: 0, length: attributed.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
        )
        write([item([(.string, "Rich"), (.rtf, rtf)])])
        let result = makeReader().read()
        let snapshot = try #require(result.snapshot)
        #expect(snapshot.rtf == rtf)
    }

    @Test("Copied file is unsupported")
    func copiedFile() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cc-test-\(UUID().uuidString).txt")
        try Data("x".utf8).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        write([fileURL as NSURL])
        #expect(makeReader().read() == .unsupported)
    }

    @Test("Image-only pasteboard is unsupported")
    func imageOnly() throws {
        let bitmap = try #require(
            NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2,
                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                             isPlanar: false, colorSpaceName: .deviceRGB,
                             bytesPerRow: 0, bitsPerPixel: 0)
        )
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        write([item([(.png, png)])])
        #expect(makeReader().read() == .unsupported)
    }

    @Test("Whitespace-only plain text still counts as content")
    func whitespaceOnly() {
        write([item([(.string, "   ")])])
        guard case .text(let snapshot) = makeReader().read() else {
            Issue.record("expected text")
            return
        }
        #expect(snapshot.plainText == "   ")
    }

    @Test("UTF-16 external flavour is decoded when no UTF-8 string exists")
    func utf16External() throws {
        let text = "こんにちは"
        let data = try #require(text.data(using: .utf16LittleEndian))
        write([item([(NSPasteboard.PasteboardType("public.utf16-external-plain-text"), data)])])
        #expect(makeReader().read() == .text(ClipboardSnapshot(plainText: text, html: nil, rtf: nil)))
    }
}

extension ClipboardReadResult {
    fileprivate var snapshot: ClipboardSnapshot? {
        guard case .text(let snapshot) = self else { return nil }
        return snapshot
    }
}
