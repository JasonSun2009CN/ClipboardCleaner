import AppKit
import Foundation

/// Reads the current clipboard into a `ClipboardSnapshot`.
///
/// Never polls: this is only called when the user triggers Paste Clean.
struct ClipboardReader {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    func read() -> ClipboardReadResult {
        // A copied file or image is explicitly out of scope for v1,
        // even if a name/path string flavour happens to ride along.
        if containsFileOrImage {
            return .unsupported
        }

        let snapshot = ClipboardSnapshot(
            plainText: readPlainText(),
            html: readString(type: .html),
            rtf: readData(type: .rtf)
        )

        return snapshot.hasContent ? .text(snapshot) : .empty
    }

    // MARK: - Types

    private var allTypes: [NSPasteboard.PasteboardType] {
        (pasteboard.pasteboardItems ?? []).flatMap(\.types)
    }

    private var containsFileOrImage: Bool {
        let fileAndImageTypes: Set<NSPasteboard.PasteboardType> = [
            .fileURL,
            NSPasteboard.PasteboardType("public.image"),
            .tiff,
            .png,
            NSPasteboard.PasteboardType("com.apple.cocoa.pasteboard.file-names"),
            NSPasteboard.PasteboardType("NSFilenamesPboardType"),
            NSPasteboard.PasteboardType("com.apple.pict"),
        ]
        return !Set(allTypes).isDisjoint(with: fileAndImageTypes)
    }

    // MARK: - Readers

    private func readString(type: NSPasteboard.PasteboardType) -> String? {
        pasteboard.string(forType: type)
    }

    private func readData(type: NSPasteboard.PasteboardType) -> Data? {
        pasteboard.data(forType: type)
    }

    /// Plain text flavours, in the order named by the spec (§5).
    private static let utf16External = NSPasteboard.PasteboardType("public.utf16-external-plain-text")
    private static let utf16Native = NSPasteboard.PasteboardType("public.utf16-plain-text")

    /// Reads plain text flavours in priority order (spec §5).
    ///
    /// The pasteboard server *synthesizes* a `public.utf8-plain-text`
    /// flavour from UTF-16 data and can get the byte order wrong, so any
    /// real UTF-16 flavour is decoded here first.
    private func readPlainText() -> String? {
        if let data = pasteboard.data(forType: Self.utf16External),
           let string = decodeUTF16(data, littleEndianFirst: true) {
            return string
        }
        if let data = pasteboard.data(forType: Self.utf16Native),
           let string = decodeUTF16(data, littleEndianFirst: false) {
            return string
        }
        if let string = pasteboard.string(forType: .string) {
            return string
        }
        return nil
    }

    private func decodeUTF16(_ data: Data, littleEndianFirst: Bool) -> String? {
        guard data.count >= 2 else { return nil }

        let first = [UInt8](data.prefix(2))
        let primary: String.Encoding
        let secondary: String.Encoding

        if first == [0xFF, 0xFE] {
            primary = .utf16LittleEndian
            secondary = .utf16LittleEndian
        } else if first == [0xFE, 0xFF] {
            primary = .utf16BigEndian
            secondary = .utf16BigEndian
        } else if littleEndianFirst {
            primary = .utf16LittleEndian
            secondary = .utf16BigEndian
        } else {
            primary = .utf16BigEndian
            secondary = .utf16LittleEndian
        }

        let decoded = String(data: data, encoding: primary)
            ?? String(data: data, encoding: secondary)
        // A byte-order mark may survive decoding; it is not user content.
        guard var result = decoded else { return nil }
        if result.hasPrefix("\u{FEFF}") {
            result.removeFirst()
        }
        return result
    }
}
