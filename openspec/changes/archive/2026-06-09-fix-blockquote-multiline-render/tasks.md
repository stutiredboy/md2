## 1. Implementation

- [x] 1.1 In `Sources/MD2Core/MarkdownRenderer.swift`, change `paragraphHTML` so the non-last-line (soft break) branch emits `<br>` instead of a trailing space.
- [x] 1.2 Confirm the hard-break branch (trailing `  ` or `\`) and final-line branch are unchanged, so both soft and hard breaks now converge on `<br>` and the last line emits no trailing break.
- [x] 1.3 Confirm `blockquoteBlock` needs no change (it inherits via `renderBody` → `paragraphHTML`).

## 2. Tests

- [x] 2.1 Audit `Tests/MD2CoreTests/MarkdownRendererTests.swift` and `Tests/MD2CoreTests/MarkdownSyntaxCoverageTests.swift`; update any assertion that relied on adjacent paragraph lines being joined by a space. (No assertion relied on space-joining — all use fragment-based `.contains()`.)
- [x] 2.2 Add a test: a multi-line paragraph renders with `<br>` between lines (not a joining space).
- [x] 2.3 Add a test for the reported case: a three-line blockquote renders three separate lines (`<br>` present) and does NOT collapse to `asdfasdf asdfasdf asdfasdf`.
- [x] 2.4 Add/keep a test confirming a blank line still separates two `<p>` blocks with no bridging `<br>`.
- [x] 2.5 Keep the existing hard-break `<br>` assertion passing (added `backslashHardBreakRemovesMarkerAndEmitsBr`).

## 3. Docs & Verification

- [x] 3.1 Update `Docs/MarkdownSupport.md` to state that soft line breaks render as visible line breaks in paragraphs and blockquotes.
- [x] 3.2 Run `swift test` (or the MD2Core test target) and confirm all tests pass. (94 tests in 13 suites passed.)
- [x] 3.3 Verify the reported blockquote sample renders as three lines. Verified at the render layer that drives the preview: `ContentView` displays `document.rendered.html` = `MarkdownRenderer().render(text).html`, which for the reported sample yields `asdfasdf<br>asdfasdf<br>asdfasdf` (asserted by `multiLineBlockquotePreservesLineBreaks`); the preview is a thin WebView that renders `<br>` as a line break.
