import Foundation

/// The default "Plain Text" path: remove formatting, change nothing else.
///
/// Per spec §17 this mode only normalizes line endings. Multiple spaces,
/// indentation, and trailing whitespace are exactly what the user copied
/// and must survive untouched.
enum PlainTextCleaner {
    static func clean(_ text: String) -> String {
        normalizeLineEndings(text)
    }

    /// CRLF / CR → LF.
    ///
    /// Note: `String.contains("\r")` cannot be used as a guard here —
    /// a CRLF pair is a single grapheme cluster, so the CR inside it is
    /// invisible to `contains(Character)`.
    static func normalizeLineEndings(_ text: String) -> String {
        guard text.unicodeScalars.contains("\r") else { return text }
        return text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }
}
