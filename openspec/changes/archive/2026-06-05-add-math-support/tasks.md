## 1. Bundle the math engine (offline assets)

- [x] 1.1 Add KaTeX assets (minified CSS, JS, and required woff2 fonts) under `Resources/katex/`
- [x] 1.2 Declare the KaTeX assets as bundle resources for the relevant target in `Package.swift`
- [x] 1.3 Add a helper in `MD2Core` that loads the bundled CSS/JS as strings (and base64-embeds fonts) for inlining into preview HTML

## 2. Math detection in the renderer

- [x] 2.1 Add block-math detection in `MarkdownRenderer`: recognize `$$`-delimited display blocks (single-line `$$...$$` and multi-line, opening/closing `$$` lines), with precedence over paragraph/code-block handling
- [x] 2.2 Add inline-math detection in the inline parser: recognize `$...$` spans with the delimiter rules (no whitespace just inside, `\$` is literal, unmatched `$` is literal)
- [x] 2.3 Ensure inline code and fenced/indented code blocks take precedence so `$...$`/`$$...$$` inside code stays literal
- [x] 2.4 Emit math as dedicated wrapper elements (inline span / display div) carrying the raw TeX as HTML-escaped text content, bypassing the normal inline Markdown pipeline

## 3. Typeset in the preview

- [x] 3.1 Inject bundled KaTeX CSS and JS into `htmlDocument(body:)` `<head>` (inlined for offline file-URL loading)
- [x] 3.2 Add an init script that typesets the math wrapper elements with KaTeX, using `throwOnError: false` and `displayMode` for block elements
- [x] 3.3 Add CSS so typeset math inherits `--text` foreground color for light/dark legibility
- [x] 3.4 Verify assets load under the `loadFileURL` preview path in `MarkdownPreviewView` (no network, no broken relative URLs)

## 4. Tests

- [x] 4.1 Add tests for inline math detection and HTML emission (`$E=mc^2$`, underscores not turned into emphasis)
- [x] 4.2 Add tests for block math detection (single-line and multi-line `$$...$$`)
- [x] 4.3 Add false-positive tests: `$5`/`$10` currency, escaped `\$`, lone unmatched `$`
- [x] 4.4 Add precedence tests: `$x$` inside inline code and inside a fenced code block stay literal
- [x] 4.5 Run `swift test` (31 tests pass) and verify offline math rendering in a headless browser; the GUI `Scripts/functional_test.sh` is unrelated to math and requires an interactive accessibility session, so offline KaTeX rendering was verified directly instead

## 5. Documentation

- [x] 5.1 Move math from "Not Yet Supported" to the verified matrix in `Docs/MarkdownSupport.md` (note KaTeX subset limitations)
- [x] 5.2 Add math to the feature list in `README.md` and `README.zh-CN.md`
