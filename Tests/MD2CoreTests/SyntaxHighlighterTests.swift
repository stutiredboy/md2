import Testing
@testable import MD2Core

struct SyntaxHighlighterTests {
    @Test func highlightsMainstreamLanguageKeywordsAndStrings() {
        let cases: [(language: String, code: String, keyword: String, extraToken: String)] = [
            ("python", #"def hello():\n    return "ok""#, "def", "return"),
            ("java", #"class App { public static void main(String[] args) { String value = "ok"; return; } }"#, "class", "String"),
            ("rust", #"fn main() { let value = "ok"; }"#, "fn", "let"),
            ("cpp", #"int main() { std::string value = "ok"; return 0; }"#, "return", "int"),
            ("c", #"int main(void) { char *value = "ok"; return 0; }"#, "return", "char"),
            ("sh", #"if true; then echo "ok"; fi"#, "if", "then"),
            ("perl", #"sub hello { my $value = "ok"; return $value; }"#, "sub", "my"),
            ("go", #"func main() { var value string = "ok" }"#, "func", "var")
        ]

        for testCase in cases {
            let html = SyntaxHighlighter.highlightedHTML(
                for: testCase.code,
                language: testCase.language
            )

            #expect(
                html.contains(#"<span class="tok-keyword">\#(testCase.keyword)</span>"#),
                "Expected \(testCase.language) keyword \(testCase.keyword) to be highlighted."
            )
            #expect(
                html.contains(#"<span class="tok-keyword">\#(testCase.extraToken)</span>"#) ||
                    html.contains(#"<span class="tok-type">\#(testCase.extraToken)</span>"#),
                "Expected \(testCase.language) token \(testCase.extraToken) to be highlighted."
            )
            #expect(
                html.contains(#"<span class="tok-string">&quot;ok&quot;</span>"#),
                "Expected \(testCase.language) string literal to be highlighted."
            )
        }
    }

    @Test func highlightsCommentsNumbersAndFunctions() {
        let html = SyntaxHighlighter.highlightedHTML(
            for: """
            // greet
            func greet(name string) { return 42 }
            """,
            language: "go"
        )

        #expect(html.contains(#"<span class="tok-comment">// greet</span>"#))
        #expect(html.contains(#"<span class="tok-function">greet</span>"#))
        #expect(html.contains(#"<span class="tok-number">42</span>"#))
    }

    @Test func escapesUnsupportedLanguagesWithoutTokenSpans() {
        let html = SyntaxHighlighter.highlightedHTML(
            for: #"value = "<safe>" & more"#,
            language: "unknown"
        )

        #expect(html == #"value = &quot;&lt;safe&gt;&quot; &amp; more"#)
        #expect(!html.contains(#"<span class="tok-"#))
    }
}
