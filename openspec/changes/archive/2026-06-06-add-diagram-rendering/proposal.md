## Why

Technical writing frequently relies on diagrams — architecture flows, process flowcharts, and interaction sequences — yet Markdown2 currently renders fenced code blocks for these as plain, unrendered source text. Adding offline diagram rendering brings Markdown2 to parity with Typora and other editors for the most common diagram notations, without breaking the app's no-network guarantee.

## What Changes

- Recognize three new fenced code-block languages in the Read-mode preview and render them as diagrams instead of plain code:
  - ` ```mermaid ` → rendered with [Mermaid](https://mermaid.js.org/) (covers Mermaid flowcharts, sequence diagrams, class diagrams, state diagrams, etc.).
  - ` ```flow ` → rendered with [flowchart.js](https://flowchart.js.org/) for its dedicated flowchart DSL.
  - ` ```sequence ` → rendered with [js-sequence-diagrams](https://bramp.github.io/js-sequence-diagrams/) for its dedicated sequence DSL.
- Bundle the diagram engine assets with the app and inline them into the generated preview HTML so rendering works fully offline (same approach as the existing KaTeX math assets).
- Render each diagram in place where its fenced block appears, preserving document order and surrounding content.
- Gracefully degrade: when diagram source fails to parse, show the offending source (or an inline error) rather than blanking the rest of the preview.
- Ensure diagrams are legible in both light and dark appearance.

## Capabilities

### New Capabilities
- `diagram-rendering`: Detect `mermaid`, `flow`, and `sequence` fenced code blocks in Markdown source, emit their source safely into the preview HTML, and render them offline as diagrams in the Read-mode preview.

### Modified Capabilities
<!-- None. Existing math-rendering and Markdown behavior is unchanged; diagram blocks are a new branch of fenced-code handling. -->

## Impact

- **Code**: `Sources/MD2Core/MarkdownRenderer.swift` (fenced-block branch + HTML/script injection), a new `DiagramAssets` loader analogous to `MathAssets`, new bundled JS assets under `Sources/MD2Core/Resources/`, and `Package.swift` resource declarations.
- **Dependencies**: Adds bundled (vendored, offline) Mermaid, flowchart.js (+ Raphael), and js-sequence-diagrams (+ underscore/Raphael) JavaScript. No runtime network dependency.
- **Docs**: `Docs/MarkdownSupport.md` and `README.md` / `README.zh-CN.md` feature lists updated to mention diagram support.
- **Tests**: New `MD2Core` tests covering diagram-block detection and HTML emission.
