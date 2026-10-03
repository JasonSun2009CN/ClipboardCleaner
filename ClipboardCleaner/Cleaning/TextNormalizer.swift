import Foundation

/// The opt-in "Normalize" mode (spec §18). Applied only when the user
/// selects it — the default mode never runs this code.
///
/// - CRLF / CR → LF
/// - runs of spaces/tabs → a single space
/// - more than one consecutive blank line → one blank line
/// - trailing whitespace per line → removed
/// - leading/trailing blank lines → removed
enum TextNormalizer {
    static func normalize(_ text: String) -> String {
        let unified = PlainTextCleaner.normalizeLineEndings(text)

        var lines: [String] = []
        for rawLine in unified.components(separatedBy: "\n") {
            let collapsed = collapseHorizontalWhitespace(rawLine)
            if collapsed.isEmpty {
                // Collapse blank-line runs; ignore leading blanks.
                if lines.last?.isEmpty == true || lines.isEmpty {
                    continue
                }
                lines.append("")
            } else {
                lines.append(collapsed)
            }
        }
        while lines.last?.isEmpty == true {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
    }

    /// Collapses space/tab runs to one space and trims the line's end.
    private static func collapseHorizontalWhitespace(_ line: String) -> String {
        guard line.contains(" ") || line.contains("\t") else { return line }

        var result = ""
        var pendingSpace = false
        for char in line {
            if char == " " || char == "\t" {
                pendingSpace = !result.isEmpty
            } else {
                if pendingSpace {
                    result.append(" ")
                    pendingSpace = false
                }
                result.append(char)
            }
        }
        // pendingSpace at end of line == trailing whitespace: dropped.
        return result
    }
}
