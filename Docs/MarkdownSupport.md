# Markdown2 Markdown Support

Markdown2 aims for a compact Typora-like writing and reading flow. It does not claim full Typora parity; Typora includes product features and external renderers that are outside this first native implementation.

## Verified in Tests

- Headings: ATX (`#`) and Setext (`===`, `---`).
- Paragraphs, hard line breaks, horizontal rules.
- Blockquotes, including Markdown rendered inside quote blocks.
- Lists: ordered, unordered, and GFM task lists.
- Tables: GFM pipe tables with left, center, and right alignment.
- Code: fenced code blocks, indented code blocks, and inline code.
- Syntax highlighting: lightweight keyword/type/string/comment/number/function highlighting for Python, Java, Rust, C++, C, shell, Perl, Go, Swift, JavaScript, and TypeScript code fences.
- Inline styles: strong, emphasis, strong-emphasis, strikethrough.
- Links and images, including optional title text.
- Autolinks such as `<https://example.com>`.
- Backslash escapes and HTML entities.
- Safe inline HTML tags; unsafe tags such as `<script>` are escaped.
- YAML front matter.
- `[TOC]` generated from headings.
- Math: inline TeX `$...$` and display TeX `$$...$$` (single- and multi-line), typeset offline with bundled KaTeX, including the mhchem extension for chemistry expressions such as `\ce{H2SO4}`. Currency text (`$5`), escaped `\$`, and `$` inside code are left literal. Note: KaTeX supports a subset of LaTeX, so commands outside that subset render as an inline error rather than typeset output.
- Diagrams: `mermaid`, `flow` (flowchart.js), and `sequence` (js-sequence-diagrams) fenced code blocks, rendered offline with bundled engine assets in the Read-mode preview. Invalid diagram source falls back to showing its raw text instead of blanking the preview. Other code-fence languages are unaffected.
- CJK text in headings, paragraphs, tables, and inline styles.

## Not Yet Supported

- Footnotes.
- Semantic syntax analysis, compiler-aware highlighting, and language-server features.
- Typora image upload, drag/drop insertion, image resize UI, and configurable image root paths.
- Import/export formats such as PDF, DOCX, LaTeX, Epub.
- Focus mode, typewriter mode, auto-pairing, and custom theme management.
- Full CommonMark conformance for every nested/container edge case.
