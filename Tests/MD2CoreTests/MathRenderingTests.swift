import Testing
@testable import MD2Core

struct MathRenderingTests {
    // MARK: Inline math (4.1)

    @Test func rendersInlineMath() {
        let document = MarkdownRenderer().render("The mass is $E = mc^2$ today.")

        #expect(document.html.contains(#"<span class="math math-inline">E = mc^2</span>"#))
        // The surrounding prose is preserved around the math span.
        #expect(document.html.contains("The mass is <span"))
        #expect(document.html.contains("</span> today."))
    }

    @Test func inlineMathIsNotProcessedAsMarkdown() {
        let document = MarkdownRenderer().render("$a_*b_*c$")

        // Underscores/asterisks are kept as literal TeX, not turned into emphasis.
        #expect(document.html.contains(#"<span class="math math-inline">a_*b_*c</span>"#))
        #expect(!document.html.contains("<em>"))
        #expect(!document.html.contains("<strong>"))
    }

    @Test func inlineMathEscapesHTMLSensitiveCharacters() {
        let document = MarkdownRenderer().render("$a < b & c$")

        // TeX is HTML-escaped so the DOM text content stays valid.
        #expect(document.html.contains(#"<span class="math math-inline">a &lt; b &amp; c</span>"#))
    }

    // MARK: Block math (4.2)

    @Test func rendersSingleLineDisplayMath() {
        let document = MarkdownRenderer().render("$$a^2 + b^2 = c^2$$")

        #expect(document.html.contains(#"<div class="math math-display">a^2 + b^2 = c^2</div>"#))
    }

    @Test func rendersMultiLineDisplayMath() {
        let markdown = """
        $$
        \\int_0^1 x^2 \\, dx
        $$
        """

        let document = MarkdownRenderer().render(markdown)

        #expect(document.html.contains(#"<div class="math math-display">\int_0^1 x^2 \, dx</div>"#))
        // The `$$` delimiters are not shown as literal text.
        #expect(!document.html.contains("<p>$$"))
    }

    @Test func displayMathSeparatesFromSurroundingParagraphs() {
        let markdown = """
        Before the equation.
        $$x = 1$$
        After the equation.
        """

        let document = MarkdownRenderer().render(markdown)

        #expect(document.html.contains("<p>Before the equation.</p>"))
        #expect(document.html.contains(#"<div class="math math-display">x = 1</div>"#))
        #expect(document.html.contains("<p>After the equation.</p>"))
    }

    // MARK: False positives (4.3)

    @Test func currencyTextIsNotMath() {
        let document = MarkdownRenderer().render("It costs $5 today and $10 tomorrow.")

        #expect(!document.html.contains("class=\"math"))
        #expect(document.html.contains("$5 today and $10 tomorrow."))
    }

    @Test func escapedDollarIsLiteral() {
        let document = MarkdownRenderer().render(#"Price: \$x"#)

        #expect(!document.html.contains("class=\"math"))
        #expect(document.html.contains("Price: $x"))
    }

    @Test func loneUnmatchedDollarIsLiteral() {
        let document = MarkdownRenderer().render("A single $ sign here.")

        #expect(!document.html.contains("class=\"math"))
        #expect(document.html.contains("A single $ sign here."))
    }

    @Test func openingDollarFollowedBySpaceIsNotMath() {
        let document = MarkdownRenderer().render("Use $ x for the var $ end.")

        #expect(!document.html.contains("class=\"math"))
    }

    // MARK: Code precedence (4.4)

    @Test func inlineMathInsideInlineCodeStaysLiteral() {
        let document = MarkdownRenderer().render("use `$x$` here")

        #expect(!document.html.contains("class=\"math"))
        #expect(document.html.contains("<code>$x$</code>"))
    }

    @Test func displayMathInsideFencedCodeStaysLiteral() {
        let markdown = """
        ```
        $$x^2$$
        ```
        """

        let document = MarkdownRenderer().render(markdown)

        #expect(!document.html.contains("class=\"math"))
        #expect(document.html.contains("$$x^2$$"))
    }

    // MARK: Offline assets (5.x support)

    @Test func previewHTMLBundlesKaTeXAssetsForOfflineRendering() {
        let document = MarkdownRenderer().render("$x$")

        // KaTeX CSS (with embedded fonts) and JS are inlined — no network needed.
        #expect(document.html.contains(".katex"))
        #expect(document.html.contains("data:font/woff2;base64,"))
        #expect(document.html.contains("katex.render"))
    }

    @Test func previewHTMLBundlesMhchemExtension() {
        let document = MarkdownRenderer().render(#"$\ce{CH4 + 2 O2}$"#)

        // The mhchem extension is inlined so `\ce{...}` chemistry renders.
        #expect(document.html.contains("__mhchemParse") || document.html.contains("mhchem"))
        #expect(document.html.contains(#"<span class="math math-inline">\ce{CH4 + 2 O2}</span>"#))
    }
}
