# MD2 Markdown Support

MD2 aims for a compact Typora-like writing and reading flow. It does not claim full Typora parity; Typora includes product features and external renderers that are outside this first native implementation.

## Verified in Tests

- Headings: ATX (`#`) and Setext (`===`, `---`).
- Paragraphs, hard line breaks, horizontal rules.
- Blockquotes, including Markdown rendered inside quote blocks.
- Lists: ordered, unordered, and GFM task lists.
- Tables: GFM pipe tables with left, center, and right alignment.
- Code: fenced code blocks, indented code blocks, and inline code.
- Inline styles: strong, emphasis, strong-emphasis, strikethrough.
- Links and images, including optional title text.
- Autolinks such as `<https://example.com>`.
- Backslash escapes and HTML entities.
- Safe inline HTML tags; unsafe tags such as `<script>` are escaped.
- YAML front matter.
- `[TOC]` generated from headings.
- CJK text in headings, paragraphs, tables, and inline styles.
- The course report fixture at `/Users/tiredboy/work/github/ScutMemHomework/论文写作与学术规范/第一次课程作业/三篇论文深度评审报告_独立分析.md`.

## Not Yet Supported

- MathJax/LaTeX rendering.
- Mermaid, flowchart.js, and sequence diagrams.
- Footnotes.
- Full syntax highlighting beyond preserving the code block language class.
- Typora image upload, drag/drop insertion, image resize UI, and configurable image root paths.
- Import/export formats such as PDF, DOCX, LaTeX, Epub.
- Focus mode, typewriter mode, auto-pairing, and custom theme management.
- Full CommonMark conformance for every nested/container edge case.
