import Testing
@testable import MD2Core

struct FootnoteRenderingTests {
    // MARK: Inline reference rendering (5.1)

    @Test func rendersReferenceAndDefinition() {
        let markdown = """
        Here is a statement.[^1] And more text.

        [^1]: The supporting detail.
        """
        let html = MarkdownRenderer().render(markdown).html

        // Reference becomes a numbered superscript link to the definition.
        #expect(html.contains(##"<sup class="footnote-ref"><a id="fnref-1" href="#fn-1">1</a></sup>"##))
        // The raw reference syntax does not survive in the body.
        #expect(!html.contains("[^1]"))
        // A footnotes section entry is emitted for the definition.
        #expect(html.contains(#"<section class="footnotes">"#))
        #expect(html.contains(#"<li id="fn-1">"#))
        #expect(html.contains("The supporting detail."))
        // The entry links back to the reference site.
        #expect(html.contains(##"href="#fnref-1""##))
    }

    // MARK: First-reference ordering (5.2)

    @Test func numbersByFirstReferenceOrder() {
        let markdown = """
        First[^note] then second[^alpha].

        [^alpha]: Alpha content.
        [^note]: Note content.
        """
        let html = MarkdownRenderer().render(markdown).html

        // `note` is referenced first, so it is footnote 1 despite alphabetical order.
        #expect(html.contains(##"<a id="fnref-note" href="#fn-note">1</a>"##))
        #expect(html.contains(##"<a id="fnref-alpha" href="#fn-alpha">2</a>"##))

        // The section lists `note` before `alpha`.
        let noteIndex = html.range(of: #"<li id="fn-note">"#)
        let alphaIndex = html.range(of: #"<li id="fn-alpha">"#)
        #expect(noteIndex != nil)
        #expect(alphaIndex != nil)
        if let noteIndex, let alphaIndex {
            #expect(noteIndex.lowerBound < alphaIndex.lowerBound)
        }
    }

    // MARK: Multi-line definitions (5.3)

    @Test func preservesMultiLineDefinitionContent() {
        let markdown = """
        See the note.[^long]

        [^long]: First line.
            Second line.
        """
        let html = MarkdownRenderer().render(markdown).html

        #expect(html.contains("First line."))
        #expect(html.contains("Second line."))
    }

    // MARK: Edge cases (5.4)

    @Test func referenceWithoutDefinitionStaysLiteral() {
        let html = MarkdownRenderer().render("Dangling.[^missing]").html

        #expect(html.contains("[^missing]"))
        #expect(!html.contains(#"<sup class="footnote-ref">"#))
        #expect(!html.contains(#"<section class="footnotes">"#))
    }

    @Test func unreferencedDefinitionIsOmitted() {
        let markdown = """
        Body text with no references.

        [^unused]: Never cited.
        """
        let html = MarkdownRenderer().render(markdown).html

        #expect(!html.contains(#"<section class="footnotes">"#))
        #expect(!html.contains("Never cited."))
        // The definition line itself does not render in the body.
        #expect(!html.contains("[^unused]"))
    }

    // MARK: Duplicate references (5.5)

    @Test func duplicateReferencesShareOneDefinition() {
        let markdown = """
        First use.[^1] Second use.[^1]

        [^1]: Shared.
        """
        let html = MarkdownRenderer().render(markdown).html

        // Both references render as footnote 1 with distinct back-reference anchors.
        #expect(html.contains(##"<a id="fnref-1" href="#fn-1">1</a>"##))
        #expect(html.contains(##"<a id="fnref-1-2" href="#fn-1">1</a>"##))

        // The unsuffixed anchor belongs to the first occurrence in reading order.
        let firstReference = html.range(of: ##"<a id="fnref-1" href="#fn-1">1</a>"##)
        let secondReference = html.range(of: ##"<a id="fnref-1-2" href="#fn-1">1</a>"##)
        #expect(firstReference != nil)
        #expect(secondReference != nil)
        if let firstReference, let secondReference {
            #expect(firstReference.lowerBound < secondReference.lowerBound)
        }

        // The single entry provides a back-reference for each occurrence.
        #expect(html.contains(##"href="#fnref-1""##))
        #expect(html.contains(##"href="#fnref-1-2""##))

        // Only one definition entry exists.
        let entryCount = html.components(separatedBy: #"<li id="fn-1">"#).count - 1
        #expect(entryCount == 1)
    }

    @Test func sanitizesCollidingLabelsIntoUniqueAnchors() {
        let markdown = """
        First[^a+b] then second[^a/b].

        [^a+b]: Plus label.
        [^a/b]: Slash label.
        """
        let html = MarkdownRenderer().render(markdown).html

        #expect(html.contains(##"<a id="fnref-a-b" href="#fn-a-b">1</a>"##))
        #expect(html.contains(##"<a id="fnref-a-b-2" href="#fn-a-b-2">2</a>"##))
        #expect(html.contains(#"<li id="fn-a-b">Plus label."#))
        #expect(html.contains(#"<li id="fn-a-b-2">Slash label."#))
    }

    // MARK: Code precedence (5.6)

    @Test func footnoteSyntaxInsideInlineCodeStaysLiteral() {
        // The reference appears only inside inline code, even though a real
        // definition exists, so it must stay literal and create no link.
        let markdown = """
        Use `[^1]` as a label.

        [^1]: A real definition.
        """
        let html = MarkdownRenderer().render(markdown).html

        #expect(html.contains("<code>[^1]</code>"))
        #expect(!html.contains(#"<sup class="footnote-ref">"#))
        // Defined but only referenced from code, so no section entry is emitted.
        #expect(!html.contains(#"<section class="footnotes">"#))
    }

    @Test func footnoteDefinitionInsideFencedCodeStaysLiteral() {
        let markdown = """
        ```
        [^1]: not a footnote
        ```

        Body referencing [^1] here is undefined.
        """
        let html = MarkdownRenderer().render(markdown).html

        // The fenced block keeps the literal text and creates no footnote entry.
        #expect(html.contains("[^1]: not a footnote"))
        #expect(!html.contains(#"<section class="footnotes">"#))
        // The reference has no real definition, so it stays literal.
        #expect(html.contains("[^1]"))
    }

    @Test func footnoteDefinitionInsideIndentedCodeStaysLiteral() {
        let markdown = """
        Paragraph.

            [^1]: not a footnote

        Reference [^1] is undefined.
        """
        let html = MarkdownRenderer().render(markdown).html

        #expect(!html.contains(#"<section class="footnotes">"#))
        #expect(!html.contains(#"<sup class="footnote-ref">"#))
    }

    // MARK: No section when unused (5.7)

    @Test func noFootnotesSectionWithoutReferences() {
        let html = MarkdownRenderer().render("Just a plain paragraph.").html

        #expect(!html.contains(#"<section class="footnotes">"#))
    }
}
