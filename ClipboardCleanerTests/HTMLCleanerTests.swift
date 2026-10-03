import Testing
@testable import ClipboardCleaner

@Suite("HTMLCleaner")
struct HTMLCleanerTests {
    private func clean(_ html: String) -> String {
        HTMLCleaner.convert(html)
    }

    // MARK: - Spec §37 core cases

    @Test("Paragraphs become separate lines")
    func paragraphs() {
        #expect(clean("<p>Hello</p><p>World</p>") == "Hello\nWorld")
    }

    @Test("Pretty-printed markup collapses to the same result")
    func prettyPrinted() {
        let html = "<div>\n  <p>Hello</p>\n  <p>World</p>\n</div>"
        #expect(clean(html) == "Hello\nWorld")
    }

    @Test("Unordered lists use bullets")
    func unorderedList() {
        let html = "<ul><li>Apple</li><li>Banana</li></ul>"
        #expect(clean(html) == "• Apple\n• Banana")
    }

    @Test("Ordered lists are numbered")
    func orderedList() {
        let html = "<ol><li>A</li><li>B</li></ol>"
        #expect(clean(html) == "1. A\n2. B")
    }

    @Test("Nested lists keep two levels of hierarchy")
    func nestedLists() {
        let html = """
        <ul>
          <li>Apple
            <ul>
              <li>Red Apple</li>
              <li>Green Apple</li>
            </ul>
          </li>
          <li>Banana</li>
        </ul>
        """
        let expected = "• Apple\n  • Red Apple\n  • Green Apple\n• Banana"
        #expect(clean(html) == expected)
    }

    @Test("Links contribute their text only, never the URL")
    func links() {
        #expect(clean(#"<a href="https://example.com">Example</a>"#) == "Example")
        let html = #"<p>See <a href="https://openai.com">OpenAI</a> for details</p>"#
        #expect(clean(html) == "See OpenAI for details")
    }

    @Test("Images contribute their alt text only")
    func images() {
        #expect(clean(#"<img alt="Apple logo" src="https://x/logo.png">"#) == "Apple logo")
        #expect(clean(#"<img src="https://x/logo.png">"#) == "")
        #expect(clean(#"<img alt="   " src="x">"#) == "")
    }

    @Test("HTML entities are decoded")
    func entities() {
        #expect(clean("<p>Tom &amp; Jerry</p>") == "Tom & Jerry")
        #expect(clean("<p>&lt;b&gt;bold&lt;/b&gt;</p>") == "<b>bold</b>")
        #expect(clean("<p>&quot;q&quot; &apos;a&apos;</p>") == #""q" 'a'"#)
        #expect(clean("<p>&#65;&#x4F60;</p>") == "A你")
    }

    @Test("Non-breaking spaces collapse like ordinary spaces")
    func nonBreakingSpaces() {
        #expect(clean("Hello&nbsp;&nbsp;World") == "Hello World")
    }

    @Test("Ampersands that are not references stay untouched")
    func literalAmpersands() {
        #expect(clean("AT&T; is fine") == "AT&T; is fine")
        #expect(clean("Tom & Jerry") == "Tom & Jerry")
        #expect(clean("5 &lt; 7 & 9") == "5 < 7 & 9")
    }

    @Test("<br> produces a newline, repeated <br> does not pile up")
    func lineBreaks() {
        #expect(clean("Hello<br>World") == "Hello\nWorld")
        #expect(clean("Hello<br><br><br>World") == "Hello\nWorld")
        #expect(clean("Hello<br>\n   World") == "Hello\nWorld")
    }

    // MARK: - Spec §13/14 whitespace and code

    @Test("Inline whitespace runs collapse")
    func whitespaceCollapse() {
        #expect(clean("<p>Hello       World</p>") == "Hello World")
        #expect(clean("<p>Hello\n       World</p>") == "Hello World")
    }

    @Test("<pre> preserves indentation and drops only the first newline")
    func prePreservesIndentation() {
        let html = "<pre>\n    int main() {\n        return 0;\n    }\n</pre>"
        let expected = "    int main() {\n        return 0;\n    }"
        #expect(clean(html) == expected)
    }

    @Test("Code blocks keep internal structure")
    func codeBlock() {
        let html = "<pre><code>\nconst x = 10;\nconsole.log(x);\n</code></pre>"
        #expect(clean(html) == "const x = 10;\nconsole.log(x);")
    }

    @Test("Entities inside <pre> decode without re-parsing markup")
    func preEntities() {
        #expect(clean("<pre>&lt;div&gt;</pre>") == "<div>")
    }

    @Test("Inline code outside <pre> flows into the line")
    func inlineCode() {
        #expect(clean("<p>Call <code>foo()</code> now</p>") == "Call foo() now")
    }

    // MARK: - Spec §15 blockquote, §16 tables

    @Test("Blockquotes keep the > prefix")
    func blockquote() {
        #expect(clean("<blockquote>Hello world</blockquote>") == "> Hello world")
    }

    @Test("Nested blockquotes deepen the prefix")
    func nestedBlockquote() {
        #expect(clean("<blockquote><blockquote>Deep</blockquote></blockquote>") == ">> Deep")
    }

    @Test("Tables become tab-separated rows")
    func table() {
        let html = """
        <table>
          <tr><th>Name</th><th>Age</th></tr>
          <tr><td>Jason</td><td>16</td></tr>
          <tr><td>Alex</td><td>17</td></tr>
        </table>
        """
        let expected = "Name\tAge\nJason\t16\nAlex\t17"
        #expect(clean(html) == expected)
    }

    // MARK: - Structure preservation

    @Test("Headings and body text land on separate lines")
    func headings() {
        #expect(clean("<h1>Title</h1>Body") == "Title\nBody")
    }

    @Test("Inline formatting disappears but spacing survives")
    func inlineFormatting() {
        let html = "<p><strong>Hello</strong> <em>World</em></p>"
        #expect(clean(html) == "Hello World")
    }

    @Test("Chat-style rich copy converts to structured plain text")
    func chatScenario() {
        let html = """
        <p><strong>Hello</strong></p>
        <p>Here is some text:</p>
        <ol><li>First</li><li>Second</li></ol>
        <p><a href="https://example.com">Click here</a></p>
        """
        let expected = "Hello\nHere is some text:\n1. First\n2. Second\nClick here"
        #expect(clean(html) == expected)
    }

    @Test("Markdown-style markers from rich sources do not leak through")
    func noMarkdownBleed() {
        // Sources that hand over Markdown usually also provide HTML.
        let html = "<p><strong>Hello</strong></p><p>[Click here](https://x.com)</p>"
        #expect(clean(html) == "Hello\n[Click here](https://x.com)")
    }

    // MARK: - Spec §37 empty elements

    @Test("Empty elements produce no blank lines")
    func emptyElements() {
        #expect(clean("<div></div><span></span>") == "")
        #expect(clean("<p></p>") == "")
        #expect(clean("<div>\n\n</div>\n<div>A</div>") == "A")
        #expect(clean("<ul></ul>") == "")
        #expect(clean("<table></table>") == "")
    }

    // MARK: - Spec §38 malformed HTML

    @Test("Missing closing tags still yield the text")
    func missingClosers() {
        #expect(clean("<p>Hello<p>World") == "Hello\nWorld")
        #expect(clean("<div><ul><li>A<li>B") == "• A\n• B")
    }

    @Test("Unterminated tags and stray angle brackets do not crash")
    func unterminated() {
        #expect(clean("<p unclosed") == "")
        // A lone bracket is literal text, like "1 < 2".
        #expect(clean("<") == "<")
        #expect(clean("</") == "</")
        #expect(clean("1 < 2 and 3 > 2") == "1 < 2 and 3 > 2")
    }

    @Test("Comments are dropped")
    func comments() {
        #expect(clean("<!-- note --><p>Hi</p>") == "Hi")
        #expect(clean("before<!-- unterminated") == "before")
        #expect(clean("<!--<p>x</p>-->after") == "after")
    }

    @Test("Script and style content never appears in the output")
    func scriptAndStyle() {
        #expect(clean("<p>Hi</p><script>var a = \"<p>bad</p>\"; if (x < y) {}</script>") == "Hi")
        #expect(clean("<style>p { color: red; }</style>Hi") == "Hi")
        #expect(clean("<script>var s = '</p>';</script>Hi") == "Hi")
        #expect(clean("<title>Page Title</title>Body") == "Body")
    }

    @Test("Mismatched nesting does not crash or leak")
    func mismatchedNesting() {
        #expect(clean("<div><p>Hello</div></p>") == "Hello")
        #expect(clean("</p></div><p>Text") == "Text")
        #expect(clean("<ul><li>A</ol></ul></li>") == "• A")
    }

    @Test("DOCTYPE and processing instructions are skipped")
    func doctype() {
        #expect(clean("<!DOCTYPE html><p>Hi</p>") == "Hi")
        #expect(clean("<?xml version=\"1.0\"?><p>Hi</p>") == "Hi")
    }

    @Test("Random malformed input never crashes")
    func fuzzMalformed() {
        let pool = [
            "<p>", "</p>", "<div>", "</div>", "<>", "</>", "<!--", "-->",
            "text", "  ", "\n", "&amp;", "&#", "&", "<", ">", "\"", "'",
            "<ul><li>a", "<pre>", "</pre>", "<a href='x'>", "<td>", "<tr>",
            "<script>a < b</script>", "<br>", "<img alt=x>", "你", "😀",
            "<ol>", "</ol>", "<blockquote>", "&nbsp;", "&#x", "</ p>",
        ]

        var rng = SplitMix64(seed: 0xC0FFEE)
        for _ in 0..<300 {
            let count = Int.random(in: 1...40, using: &rng)
            var html = ""
            for _ in 0..<count {
                html += pool[Int.random(in: 0..<pool.count, using: &rng)]
            }
            _ = HTMLCleaner.convert(html) // must not trap
        }
    }
}

/// Deterministic PRNG for reproducible fuzzing.
private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
