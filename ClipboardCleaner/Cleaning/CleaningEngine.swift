import Foundation

/// Single entry point for turning a `ClipboardSnapshot` into clean text.
///
/// Representation priority (spec §7): HTML → RTF → plain text.
/// A representation that yields no usable text falls through to the next
/// one, so an HTML comment or an unparseable RTF blob never produces an
/// empty paste.
enum CleaningEngine {

    /// Returns nil when there is nothing to clean.
    static func clean(_ snapshot: ClipboardSnapshot, mode: CleaningMode) -> String? {
        guard snapshot.hasContent else { return nil }

        if let html = snapshot.html, !html.isEmpty {
            let converted = HTMLCleaner.convert(html)
            if !converted.isEmpty {
                // HTML output is final regardless of mode: the converter
                // already collapses whitespace in normal text, and running
                // Normalize over the result would destroy the indentation
                // of nested lists and <pre> code blocks.
                return converted
            }
        }

        if let rtf = snapshot.rtf, !rtf.isEmpty,
           let text = RTFHandler.plainText(from: rtf) {
            return finalize(text, mode: mode)
        }

        if let plain = snapshot.plainText, !plain.isEmpty {
            return finalize(plain, mode: mode)
        }

        return nil
    }

    private static func finalize(_ text: String, mode: CleaningMode) -> String {
        switch mode {
        case .plainText:
            return PlainTextCleaner.clean(text)
        case .normalize:
            return TextNormalizer.normalize(text)
        }
    }
}
