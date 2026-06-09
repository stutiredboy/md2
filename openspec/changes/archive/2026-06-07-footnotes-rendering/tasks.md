## 1. Footnote context & definition collection

- [x] 1.1 Add a `FootnoteContext` type (reference type or `inout` struct) in `MarkdownRenderer.swift` holding `definitions: [String: [String]]`, `order: [String]` (first-reference numbering), and `referenceCounts: [String: Int]`.
- [x] 1.2 Add a whole-document definition pre-scan that detects `^\s*\[\^(id)\]:` lines and their indented continuation lines, populating `definitions`, while skipping fenced/indented code and math blocks so code content is never absorbed.
- [x] 1.3 In `renderBody`, add `footnoteDefinitionBlock(from:startIndex:)` tried before the paragraph fallback so definition lines (and their continuations) are consumed and emit no body HTML.

## 2. Inline reference rendering

- [x] 2.1 Add a context-aware `inlineHTML(_:context:)` overload; keep the existing `inlineHTML(_:)` delegating to it with an empty/no-op context.
- [x] 2.2 Inside the protected region (after code/math/HTML protection, via the `protect(...)` placeholder mechanism), match `\[\^([^\]\s]+)\]` and, only for ids present in `definitions`, assign/lookup the display number in `order`, increment `referenceCounts`, and emit `<sup class="footnote-ref"><a id="fnref-<label>[-n]" href="#fn-<label>">N</a></sup>`.
- [x] 2.3 Leave references with no matching definition as literal text (no substitution).
- [x] 2.4 Sanitize labels with `escapeAttribute`/slug helper before placing them in `id`/`href`, with a unique fallback on collision.
- [x] 2.5 Thread the real `FootnoteContext` through the body block walk; pass the no-op context for headings/other call sites that must not consume footnotes.

## 3. Footnotes section emission

- [x] 3.1 After all blocks render, if `order` is non-empty, append `<section class="footnotes">` containing an ordered list of referenced definitions in `order` sequence, each with `id="fn-<label>"`.
- [x] 3.2 Render each definition's collected content (joined multi-line content) through `inlineHTML` so inline Markdown applies.
- [x] 3.3 Append back-reference link(s) (`<a class="footnote-backref" href="#fnref-<label>[-n]">`) to each entry — one per reference location for duplicate references.
- [x] 3.4 Omit any defined-but-unreferenced labels from the section.

## 4. Styling (light & dark)

- [x] 4.1 Add CSS in `htmlDocument` for `sup.footnote-ref a`, `section.footnotes` (top border, smaller font), and `.footnote-backref`, using `currentColor`/existing link variables so both color schemes inherit correctly.

## 5. Tests

- [x] 5.1 Test: single reference + definition renders a numbered superscript link and a footnotes section entry; raw `[^id]` syntax does not appear.
- [x] 5.2 Test: named labels are numbered by first-reference order, not label text.
- [x] 5.3 Test: multi-line definition content is preserved in the section entry.
- [x] 5.4 Test: reference without definition stays literal; definition without reference is omitted.
- [x] 5.5 Test: duplicate references share one definition with one back-reference per location.
- [x] 5.6 Test: footnote syntax inside inline code and inside fenced/indented code blocks stays literal.
- [x] 5.7 Test: no footnotes section emitted when there are no references.

## 6. Documentation / examples

- [x] 6.1 Add a "Footnotes" section to `Examples/Sample.md` demonstrating inline references (including a named label and a duplicate reference) and their definitions.
- [x] 6.2 Run the test suite (`swift test`) and verify the footnotes render correctly in the preview.
