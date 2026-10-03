import Testing
@testable import ClipboardCleaner

@Suite("TextNormalizer")
struct TextNormalizerTests {
    private func normalize(_ text: String) -> String {
        TextNormalizer.normalize(text)
    }

    @Test("Spec §18 example: space runs and CRLF collapse")
    func specExample() {
        let input = "Hello      World\r\nThis is   a test."
        #expect(normalize(input) == "Hello World\nThis is a test.")
    }

    @Test("Trailing whitespace per line is trimmed")
    func trailingWhitespace() {
        #expect(normalize("Hello   \nWorld\t\t") == "Hello\nWorld")
    }

    @Test("Repeated blank lines collapse to one")
    func blankLineRuns() {
        // Spec §18: maximum one blank line, so a blank line survives.
        #expect(normalize("A\n\n\n\n\nB") == "A\n\nB")
        #expect(normalize("A\n\n\nB\n\n\nC") == "A\n\nB\n\nC")
    }

    @Test("Leading and trailing blank lines are removed")
    func edgeBlankLines() {
        #expect(normalize("\n\n\nBody\n\n") == "Body")
        #expect(normalize("   \nBody") == "Body")
    }

    @Test("Tab runs collapse to a single space")
    func tabs() {
        #expect(normalize("a\t\tb") == "a b")
        #expect(normalize("a \t b") == "a b")
    }

    @Test("Mixed line endings unify to LF")
    func lineEndings() {
        #expect(normalize("a\r\nb\rc\nd") == "a\nb\nc\nd")
    }
}

@Suite("PlainTextCleaner")
struct PlainTextCleanerTests {
    @Test("Plain mode preserves spacing exactly")
    func preservesSpacing() {
        let input = "Hello   World\n  indented\tcode  "
        #expect(PlainTextCleaner.clean(input) == input)
    }

    @Test("Plain mode only unifies line endings")
    func onlyLineEndings() {
        #expect(PlainTextCleaner.clean("a\r\nb\rc") == "a\nb\nc")
        #expect(PlainTextCleaner.clean("a\nb") == "a\nb")
    }
}
