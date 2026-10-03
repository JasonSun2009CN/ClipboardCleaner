import Foundation

/// Converts HTML clipboard content into clean plain text.
///
/// A hand-written tolerant tokenizer plus a block-aware converter.
/// No regex tag-stripping (spec §8), no WebView, no JavaScript —
/// parse and extract text only (spec §39).
enum HTMLCleaner {

    static func convert(_ html: String) -> String {
        var tokenizer = HTMLTokenizer(html)
        let converter = Converter()
        while let token = tokenizer.next() {
            converter.consume(token)
        }
        return converter.finish()
    }
}

// MARK: - Entities

enum HTMLEntities {
    private static let named: [String: String] = [
        "amp": "&",
        "lt": "<",
        "gt": ">",
        "quot": "\"",
        "apos": "'",
        "nbsp": "\u{A0}",
        "ndash": "–",
        "mdash": "—",
        "hellip": "…",
        "lsquo": "‘",
        "rsquo": "’",
        "ldquo": "“",
        "rdquo": "”",
        "laquo": "«",
        "raquo": "»",
        "copy": "©",
        "reg": "®",
        "trade": "™",
        "middot": "·",
        "bull": "•",
        "deg": "°",
        "plusmn": "±",
        "times": "×",
        "divide": "÷",
        "frac12": "½",
        "sect": "§",
        "para": "¶",
        "dagger": "†",
        "euro": "€",
        "pound": "£",
        "yen": "¥",
        "cent": "¢",
    ]

    /// Decodes character references. Unknown or malformed references are
    /// left exactly as written — never destructive (spec §1.6).
    static func decode(_ text: String) -> String {
        guard text.contains("&") else { return text }

        let chars = Array(text)
        var result = ""
        result.reserveCapacity(chars.count)
        var i = 0

        while i < chars.count {
            if chars[i] == "&",
               let (decoded, length) = entity(at: chars, startingAt: i) {
                result += decoded
                i += length
            } else {
                result.append(chars[i])
                i += 1
            }
        }
        return result
    }

    /// Returns the decoded value and total consumed length (`&…;`),
    /// or nil when this ampersand is not a valid reference.
    private static func entity(at chars: [Character], startingAt start: Int) -> (String, Int)? {
        // Find the terminating ';' within a sane distance so that plain
        // text like "AT&T;" is never swallowed.
        var end = start + 1
        let limit = min(chars.count, start + 34)
        while end < limit, chars[end] != ";" {
            guard chars[end].isLetter || chars[end].isNumber || chars[end] == "#" || chars[end] == "x" else {
                return nil
            }
            end += 1
        }
        guard end < limit, chars[end] == ";", end > start + 1 else { return nil }

        let name = String(chars[(start + 1)..<end])
        let length = end - start + 1

        if name.hasPrefix("#") {
            guard let scalar = numericScalar(name) else { return nil }
            return (String(Character(scalar)), length)
        }
        guard let decoded = named[name.lowercased()] else { return nil }
        return (decoded, length)
    }

    private static func numericScalar(_ name: String) -> Unicode.Scalar? {
        let digits = String(name.dropFirst())
        guard !digits.isEmpty else { return nil }
        let value: UInt32?
        if digits.hasPrefix("x") || digits.hasPrefix("X") {
            value = UInt32(digits.dropFirst(), radix: 16)
        } else {
            value = UInt32(digits, radix: 10)
        }
        guard let value, value != 0, value != 0xD800, value < 0x110000 else { return nil }
        return Unicode.Scalar(value)
    }
}

// MARK: - Tokenizer

enum HTMLToken: Equatable {
    case text(String)
    case start(name: String, attributes: [String: String], isSelfClosing: Bool)
    case end(name: String)
}

/// Tolerant, single-pass HTML tokenizer.
/// Never throws and never loops forever on malformed input (spec §38).
struct HTMLTokenizer {
    private let chars: [Character]
    private var index = 0

    /// Elements whose content is raw text (not markup) per the HTML spec.
    private static let rawTextElements: Set<String> = ["script", "style", "title", "textarea"]

    init(_ html: String) {
        chars = Array(html)
    }

    mutating func next() -> HTMLToken? {
        while index < chars.count {
            if isTagStart(index) {
                if let token = parseTagAtCurrent() {
                    if case .start(let name, _, let selfClosing) = token,
                       Self.rawTextElements.contains(name),
                       !selfClosing {
                        skipRawTextContent(of: name)
                    }
                    return token
                }
                // Comment / doctype consumed; keep scanning.
            } else {
                return parseText()
            }
        }
        return nil
    }

    // MARK: Detection

    /// A tag only starts at `<` followed by `!`, `?`, `/`+letter, or an
    /// ASCII letter. Anything else stays literal text.
    private func isTagStart(_ i: Int) -> Bool {
        guard i < chars.count, chars[i] == "<", i + 1 < chars.count else { return false }
        let next = chars[i + 1]
        if next == "!" || next == "?" { return true }
        if next == "/" {
            guard i + 2 < chars.count else { return false }
            let after = chars[i + 2]
            return after.isASCII && after.isLetter
        }
        return next.isASCII && next.isLetter
    }

    // MARK: Text

    private mutating func parseText() -> HTMLToken {
        var text = ""
        while index < chars.count, !isTagStart(index) {
            text.append(chars[index])
            index += 1
        }
        return .text(HTMLEntities.decode(text))
    }

    // MARK: Tags

    private mutating func parseTagAtCurrent() -> HTMLToken? {
        index += 1 // consume "<"
        guard index < chars.count else { return nil }

        let marker = chars[index]
        if marker == "!" {
            parseBang()
            return nil
        }
        if marker == "?" {
            skipToGreaterThan()
            return nil
        }
        if marker == "/" {
            index += 1
            let name = readName()
            skipToGreaterThan()
            guard !name.isEmpty else { return nil }
            return .end(name: name.lowercased())
        }
        return parseStartTag()
    }

    /// Handles `<!-- … -->` and `<!DOCTYPE …>`.
    private mutating func parseBang() {
        if index + 2 < chars.count,
           chars[index + 1] == "-",
           chars[index + 2] == "-" {
            index += 3
            while index < chars.count {
                if chars[index] == "-" && index + 2 < chars.count,
                   chars[index + 1] == "-",
                   chars[index + 2] == ">" {
                    index += 3
                    return
                }
                index += 1
            }
            return // unterminated comment: consume to EOF
        }
        skipToGreaterThan()
    }

    private mutating func parseStartTag() -> HTMLToken {
        let name = readName()
        var attributes: [String: String] = [:]
        var isSelfClosing = false

        while index < chars.count {
            skipWhitespace()
            guard index < chars.count else { break }

            if chars[index] == ">" {
                index += 1
                break
            }
            if chars[index] == "/" {
                index += 1
                if index < chars.count, chars[index] == ">" {
                    isSelfClosing = true
                    index += 1
                    break
                }
                continue
            }

            let attrName = readAttributeName()
            if attrName.isEmpty {
                index += 1 // malformed char — guarantee progress
                continue
            }
            skipWhitespace()
            var value = ""
            if index < chars.count, chars[index] == "=" {
                index += 1
                skipWhitespace()
                value = readAttributeValue()
            }
            attributes[attrName.lowercased()] = HTMLEntities.decode(value)
        }

        guard !name.isEmpty else { return .text("") }
        return .start(name: name.lowercased(), attributes: attributes, isSelfClosing: isSelfClosing)
    }

    private mutating func readName() -> String {
        var name = ""
        while index < chars.count {
            let c = chars[index]
            guard c.isASCII, c.isLetter || c.isNumber else { break }
            name.append(c)
            index += 1
        }
        return name
    }

    private mutating func readAttributeName() -> String {
        var name = ""
        while index < chars.count {
            let c = chars[index]
            if c.isWhitespace || c == "=" || c == ">" || c == "/" { break }
            name.append(c)
            index += 1
        }
        return name
    }

    private mutating func readAttributeValue() -> String {
        guard index < chars.count else { return "" }
        let quote = chars[index]
        if quote == "\"" || quote == "'" {
            index += 1
            var value = ""
            while index < chars.count, chars[index] != quote {
                value.append(chars[index])
                index += 1
            }
            if index < chars.count { index += 1 } // closing quote
            return value
        }
        var value = ""
        while index < chars.count {
            let c = chars[index]
            if c.isWhitespace || c == ">" { break }
            value.append(c)
            index += 1
        }
        return value
    }

    private mutating func skipWhitespace() {
        while index < chars.count, chars[index].isWhitespace {
            index += 1
        }
    }

    private mutating func skipToGreaterThan() {
        while index < chars.count, chars[index] != ">" {
            index += 1
        }
        if index < chars.count { index += 1 }
    }

    // MARK: Raw text elements

    /// Positions the cursor at `</name` so the following `next()` call
    /// yields the end tag; otherwise consumes everything.
    private mutating func skipRawTextContent(of name: String) {
        let target = Array(name.lowercased())
        var i = index
        while i < chars.count {
            if chars[i] == "<", i + 1 < chars.count, chars[i + 1] == "/" {
                var j = i + 2
                var k = 0
                while k < target.count, j < chars.count,
                      String(chars[j]).lowercased() == String(target[k]) {
                    j += 1
                    k += 1
                }
                if k == target.count {
                    let validTerminator = j >= chars.count
                        || chars[j] == ">"
                        || chars[j] == "/"
                        || chars[j].isWhitespace
                    if validTerminator {
                        index = i
                        return
                    }
                }
                i += 1
            } else {
                i += 1
            }
        }
        index = chars.count
    }
}

// MARK: - Converter

/// Turns a token stream into plain text while preserving structure:
/// paragraphs, line breaks, lists, indentation, code blocks, quote marks.
private final class Converter {
    private struct ListContext {
        let ordered: Bool
        var counter = 0
    }

    private static let blockElements: Set<String> = [
        "p", "div", "section", "article", "header", "footer", "main", "aside", "nav",
        "h1", "h2", "h3", "h4", "h5", "h6",
        "blockquote", "ul", "ol", "li", "dl", "dt", "dd",
        "table", "tr", "thead", "tbody", "tfoot", "caption",
        "figure", "figcaption", "address", "form", "fieldset", "legend",
        "hr", "pre", "details", "summary", "menu", "center",
    ]

    /// Elements that produce no output at all.
    private static let ignoredElements: Set<String> = [
        "html", "head", "meta", "link", "base", "script", "style",
        "title", "textarea", "noscript", "template", "object", "iframe",
        "svg", "canvas", "audio", "video", "source", "track",
    ]

    private var out = ""
    private var lineStart = true
    private var pendingSpace = false
    /// Set right after a literal append (list marker, table tab) so source
    /// whitespace between the marker and its content is dropped.
    private var suppressSpace = false
    private var preDepth = 0
    private var skipLeadingNewlineInPre = false
    private var quoteDepth = 0
    private var listStack: [ListContext] = []
    private var cellIndex = 0

    func consume(_ token: HTMLToken) {
        switch token {
        case .text(let text):
            emitText(text)
        case .start(let name, let attributes, let isSelfClosing):
            handleStart(name: name, attributes: attributes, isSelfClosing: isSelfClosing)
        case .end(let name):
            handleEnd(name: name)
        }
    }

    func finish() -> String {
        var result = out
        // Trailing whitespace/newlines are output noise.
        while let last = result.last, last == "\n" || last == " " || last == "\t" || last == "\r" {
            result.removeLast()
        }
        // Leading newlines only — leading spaces may be <pre> indentation.
        while let first = result.first, first == "\n" || first == "\r" {
            result.removeFirst()
        }
        return result
    }

    // MARK: Start tags

    private func handleStart(name: String, attributes: [String: String], isSelfClosing: Bool) {
        switch name {
        case "br":
            ensureNewline()
        case "img":
            if let alt = attributes["alt"]?.trimmingCharacters(in: .whitespacesAndNewlines),
               !alt.isEmpty {
                emitText(alt)
            }
        case "pre":
            ensureNewline()
            preDepth += 1
            skipLeadingNewlineInPre = true
        case "blockquote":
            ensureNewline()
            quoteDepth += 1
        case "ul", "ol":
            ensureNewline()
            listStack.append(ListContext(ordered: name == "ol"))
        case "li":
            handleListItem()
        case "tr":
            ensureNewline()
            cellIndex = 0
        case "td", "th":
            handleTableCell()
        case "hr":
            ensureNewline()
        default:
            if Self.ignoredElements.contains(name) { return }
            if Self.blockElements.contains(name) {
                ensureNewline()
            }
        }
    }

    // MARK: End tags

    private func handleEnd(name: String) {
        switch name {
        case "br", "img", "hr", "meta", "link", "input", "source", "wbr":
            return
        case "blockquote":
            quoteDepth = max(0, quoteDepth - 1)
            ensureNewline()
        case "ul", "ol":
            if !listStack.isEmpty { listStack.removeLast() }
            ensureNewline()
        case "li":
            ensureNewline()
        case "tr":
            trimTrailingCellSeparator()
            ensureNewline()
        case "pre":
            preDepth = max(0, preDepth - 1)
            ensureNewline()
        case "td", "th":
            return
        default:
            if Self.ignoredElements.contains(name) { return }
            if Self.blockElements.contains(name) {
                ensureNewline()
            }
        }
    }

    // MARK: List items

    private func handleListItem() {
        ensureNewline()

        let depth = listStack.count
        var prefix = ""
        if depth > 1 {
            prefix = String(repeating: "  ", count: depth - 1)
        }

        if listStack.isEmpty {
            prefix += "• "
        } else if listStack[listStack.count - 1].ordered {
            listStack[listStack.count - 1].counter += 1
            prefix += "\(listStack[listStack.count - 1].counter). "
        } else {
            prefix += "• "
        }

        appendLiteral(prefix)
    }

    private func handleTableCell() {
        if cellIndex > 0 {
            pendingSpace = false
            prepareForContent()
            out.append("\t")
            lineStart = false
            suppressSpace = true
        }
        cellIndex += 1
    }

    private func trimTrailingCellSeparator() {
        if out.hasSuffix("\t") {
            out.removeLast()
            lineStart = false
        }
    }

    // MARK: Text emission

    private func emitText(_ raw: String) {
        if preDepth > 0 {
            appendRaw(raw)
            return
        }

        for char in raw {
            if char.isWhitespace {
                if !lineStart && !suppressSpace {
                    pendingSpace = true
                }
            } else {
                if pendingSpace {
                    out.append(" ")
                    pendingSpace = false
                }
                prepareForContent()
                out.append(char)
                lineStart = false
                suppressSpace = false
            }
        }
    }

    /// Verbatim emission for `<pre>` content — whitespace preserved,
    /// line endings unified, quote prefixes still applied per line.
    private func appendRaw(_ raw: String) {
        let rawChars = Array(raw)
        var i = 0
        while i < rawChars.count {
            let char = rawChars[i]

            if skipLeadingNewlineInPre {
                skipLeadingNewlineInPre = false
                if char == "\n" || char == "\r" || char == "\r\n" {
                    i += 1
                    continue
                }
            }

            switch char {
            case "\n", "\r", "\r\n":
                // CR, LF, and the CRLF cluster all become a single LF.
                out.append("\n")
                lineStart = true
                pendingSpace = false
                suppressSpace = false
                i += 1
            case "\t":
                prepareForContent()
                out.append("\t")
                lineStart = false
                i += 1
            default:
                prepareForContent()
                out.append(char)
                lineStart = false
                i += 1
            }
        }
    }

    // MARK: Line management

    /// Ensures exactly one line break before the next visible content,
    /// collapsing duplicates so empty elements never pile up blank lines.
    private func ensureNewline() {
        pendingSpace = false
        if !lineStart {
            out.append("\n")
            lineStart = true
        }
    }

    /// Applies blockquote `>` prefixes lazily, only when content follows.
    private func prepareForContent() {
        if lineStart && quoteDepth > 0 {
            out += String(repeating: ">", count: quoteDepth) + " "
            lineStart = false
        }
    }

    private func appendLiteral(_ text: String) {
        prepareForContent()
        out += text
        lineStart = false
        suppressSpace = true
    }
}
