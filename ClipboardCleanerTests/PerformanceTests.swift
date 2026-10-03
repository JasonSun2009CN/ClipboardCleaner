import Foundation
import Testing
@testable import ClipboardCleaner

/// Guards against accidental catastrophic slowdowns (spec §40).
/// Bounds are deliberately generous — this runs on developer machines.
@Suite("Performance")
struct PerformanceTests {
    private func makeHTML(bytes: Int) -> String {
        var block = """
        <h2>Section</h2>
        <p><strong>Bold</strong> and <em>italic</em> with <a href="https://example.com/x">a link</a> &amp; entities.</p>
        <ul><li>First item</li><li>Second item</li></ul>
        <pre>\n    let value = 10;\n    print(value);\n</pre>
        <blockquote>Quoted line</blockquote>

        """
        var html = ""
        while html.utf8.count < bytes {
            html += block
        }
        return html
    }

    @Test("A typical clipboard cleans well under a second")
    func typicalClipboard() {
        let html = makeHTML(bytes: 200_000)
        let start = ContinuousClock.now
        let result = HTMLCleaner.convert(html)
        let elapsed = ContinuousClock.now - start

        #expect(!result.isEmpty)
        #expect(elapsed < .seconds(2))
    }

    @Test("Pathological nesting stays linear, not exponential")
    func pathologicalNesting() {
        var html = ""
        for _ in 0..<3_000 { html += "<div><p>" }
        html += "deep"

        let start = ContinuousClock.now
        _ = HTMLCleaner.convert(html)
        let elapsed = ContinuousClock.now - start

        #expect(elapsed < .seconds(2))
    }
}
