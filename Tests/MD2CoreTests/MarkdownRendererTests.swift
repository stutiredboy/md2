import Testing
@testable import MD2Core

struct MarkdownRendererTests {
    @Test func rendersCommonMarkdownBlocks() {
        let markdown = """
        # Title

        A **bold** and *soft* [link](https://example.com).

        - [x] Done
        - [ ] Next

        | Name | Value |
        | --- | --- |
        | One | `1` |

        ```swift
        let value = "<safe>"
        ```
        """

        let document = MarkdownRenderer().render(markdown)

        #expect(document.html.contains(#"<h1 id="title">Title</h1>"#))
        #expect(document.html.contains("<strong>bold</strong>"))
        #expect(document.html.contains("<em>soft</em>"))
        #expect(document.html.contains(#"<a href="https://example.com">link</a>"#))
        #expect(document.html.contains(#"<ul class="task-list">"#))
        #expect(document.html.contains(#"<input type="checkbox" disabled checked>"#))
        #expect(document.html.contains("<table>"))
        #expect(document.html.contains("<code>1</code>"))
        #expect(document.html.contains(#"<code class="language-swift">let value = &quot;&lt;safe&gt;&quot;</code>"#))
    }

    @Test func rendersTableOfContentsFromHeadings() {
        let markdown = """
        [TOC]

        # Title
        ## Part
        """

        let document = MarkdownRenderer().render(markdown)

        #expect(document.html.contains(#"<nav class="toc">"#))
        #expect(document.html.contains(##"<a class="toc-level-1" href="#title">Title</a>"##))
        #expect(document.html.contains(##"<a class="toc-level-2" href="#part">Part</a>"##))
    }

    @Test func escapesHTMLInParagraphs() {
        let document = MarkdownRenderer().render("<script>alert(1)</script>")

        #expect(document.html.contains("&lt;script&gt;alert(1)&lt;/script&gt;"))
        #expect(!document.html.contains("<script>alert(1)</script>"))
    }

    @Test func rendersImagesWithoutDoubleEscapingAttributes() {
        let document = MarkdownRenderer().render("![A&B](images/a&b.png)")

        #expect(document.html.contains(#"<img src="images/a&amp;b.png" alt="A&amp;B">"#))
        #expect(!document.html.contains("amp;amp"))
    }
}
