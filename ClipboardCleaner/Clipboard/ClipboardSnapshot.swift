import Foundation

/// The clipboard representations captured at the moment Paste Clean is
/// triggered. Nothing is stored beyond this read — no history.
struct ClipboardSnapshot: Equatable, Sendable {
    let plainText: String?
    let html: String?
    let rtf: Data?

    static let empty = ClipboardSnapshot(plainText: nil, html: nil, rtf: nil)

    /// True when at least one representation carries content.
    var hasContent: Bool {
        if let plainText, !plainText.isEmpty { return true }
        if let html, !html.isEmpty { return true }
        if let rtf, !rtf.isEmpty { return true }
        return false
    }
}

/// Outcome of reading the current clipboard.
enum ClipboardReadResult: Equatable, Sendable {
    /// At least one text-like representation exists.
    case text(ClipboardSnapshot)
    /// Clipboard holds content v1 does not handle (files, images).
    case unsupported
    /// Clipboard is empty or holds no text at all.
    case empty
}
