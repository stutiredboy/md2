## Why

Markdown2 already renders rich Markdown but explicitly does not support math (see `Docs/MarkdownSupport.md` → "Not Yet Supported: MathJax/LaTeX rendering"). Typora-style writing flows routinely include LaTeX math for notes, papers, and technical docs, and the absence of math is one of the most visible gaps versus the Typora reference the app is modeled on. Since the reader already renders to HTML in a `WKWebView`, math can be added without a new rendering pipeline.

## What Changes

- Parse TeX/LaTeX math in Markdown source:
  - **Inline math** delimited by `$...$` (single dollar signs on one line).
  - **Block / display math** delimited by `$$...$$`, including multi-line blocks.
- Render parsed math to typeset output in the **Read** (preview) mode HTML using a bundled, offline math engine (KaTeX), so rendering works without network access and matches the app's local-file preview model.
- Treat math content as literal — math spans are *not* processed by the normal inline Markdown rules (no emphasis/escaping/HTML-escaping of TeX) and `$$` blocks are not treated as paragraphs or code.
- Avoid false positives: a lone or escaped `\$` (e.g. prices like `$5`) must not start a math span.
- In the **Write** (editor) mode, math source remains plain text; lightweight styling may mark `$`/`$$` delimited regions but full typesetting only happens in Read mode.
- Update `Docs/MarkdownSupport.md` to move math from "Not Yet Supported" to the verified support matrix, and note it in the README feature list.

## Capabilities

### New Capabilities
- `math-rendering`: Detecting inline (`$...$`) and block (`$$...$$`) TeX math in Markdown source, emitting it safely into the preview HTML, and typesetting it offline with KaTeX.

### Modified Capabilities
<!-- No existing specs in openspec/specs/; nothing else changes at the requirement level. -->

## Impact

- **Code**:
  - `Sources/MD2Core/MarkdownRenderer.swift` — math detection during inline/block parsing; emit math markup; inject the math engine into `htmlDocument(body:)`.
  - `Sources/MD2App/MarkdownPreviewView.swift` — ensure JavaScript and bundled assets load (already allows JS; offline asset loading via the file-URL load path).
  - `Sources/MD2Core/MarkdownLine.swift` / styling — optional editor-side delimiter awareness.
- **Resources / dependencies**: Bundle KaTeX (CSS + JS + fonts) as offline app resources via `Package.swift` resource declarations; no runtime network dependency.
- **Docs**: `Docs/MarkdownSupport.md`, `README.md`, `README.zh-CN.md`.
- **Tests**: `Tests/` gains coverage for math detection and HTML emission.
