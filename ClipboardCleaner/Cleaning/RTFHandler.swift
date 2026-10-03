import Foundation

/// RTF → plain text via native NSAttributedString parsing.
enum RTFHandler {
    /// Returns the RTF document's text, or nil when the data cannot be
    /// parsed as RTF.
    static func plainText(from data: Data) -> String? {
        let encodings: [String.Encoding] = [.utf8, .isoLatin1]
        for encoding in encodings {
            let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                .documentType: NSAttributedString.DocumentType.rtf,
                .characterEncoding: encoding.rawValue,
            ]
            if let attributed = try? NSAttributedString(
                data: data,
                options: options,
                documentAttributes: nil
            ) {
                return attributed.string
            }
        }
        return nil
    }
}
