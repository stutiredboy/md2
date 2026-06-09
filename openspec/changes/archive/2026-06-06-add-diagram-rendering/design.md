## Context

Markdown2 renders the Read-mode preview as a self-contained HTML document built by `MarkdownRenderer` and displayed in a `WKWebView` via `loadFileURL`. The app has a strict no-network constraint: all rendering assets are bundled and inlined into the generated HTML. The existing math feature (`MathAssets` + KaTeX) establishes the pattern this change follows:

- Assets live under `Sources/MD2Core/Resources/<engine>/` and are declared as bundle resources in `Package.swift`.
- An `enum` loader (`MathAssets`) reads them via `Bundle.module` and exposes them as strings.
- `MarkdownRenderer.htmlDocument(body:)` inlines the CSS in `<style>` and the JS in `<script>`, then runs a small bootstrap script that walks the DOM and renders flagged elements (`.math-inline`, `.math-display`).
- Block detection happens in `renderBody` via the `fencedCodeBlock` branch, which already extracts the fence `language`.

Fenced diagram blocks are a natural extension: intercept the `mermaid` / `flow` / `sequence` info strings in the fenced-code branch and emit a placeholder element carrying the raw source, then render it client-side from bundled engine assets.

## Goals / Non-Goals

**Goals:**
- Render `mermaid`, `flow`, and `sequence` fenced blocks as diagrams in the Read-mode preview.
- Fully offline rendering using vendored assets (no CDN, no network).
- In-place rendering preserving document order and surrounding content.
- Graceful failure: a bad diagram never blanks the whole preview.
- Light/dark legibility.

**Non-Goals:**
- Editing-side (Write mode) live diagram preview or inline styling.
- Interactive diagram features (pan/zoom, click handlers, hyperlinks inside diagrams).
- Exporting diagrams to SVG/PNG files.
- Supporting every Mermaid sub-diagram theme variant beyond default light/dark.
- Diagram rendering in any non-preview export path.

## Decisions

### Decision: Reuse the bundled-asset + DOM-bootstrap pattern from MathAssets
Add a `DiagramAssets` loader analogous to `MathAssets`, reading vendored JS from `Sources/MD2Core/Resources/`. Inline the scripts into the preview `<head>`/end-of-`<body>` and add a bootstrap script that finds diagram placeholders and renders them.

- **Why**: Consistency with the proven math pipeline; keeps the offline guarantee; minimal new architecture.
- **Alternatives considered**: Loading engines from a CDN (rejected — violates no-network constraint); rendering diagrams to SVG natively in Swift (rejected — no maintained Swift libraries for these DSLs, huge effort).

### Decision: Intercept diagram languages inside the fenced-code branch
In `fencedCodeBlock` (or a new `diagramBlock` checked before it), when the lower-cased info string is `mermaid`, `flow`, or `sequence`, emit a wrapper element (e.g. `<div class="diagram diagram-mermaid">…raw source…</div>`) instead of `<pre><code>`. The raw source is HTML-escaped as text content so the engine reads it verbatim from the DOM, mirroring `mathDisplayHTML`.

- **Why**: Diagram blocks are syntactically identical to code fences; the fence parser already isolates the body and language. No new block-scanning logic is needed, and code blocks for other languages are untouched.
- **Alternatives considered**: A separate top-level block scanner (rejected — duplicates fence parsing); a post-render HTML transform (rejected — fragile, re-parses HTML).

### Decision: One placeholder class per engine; a single bootstrap dispatches per class
The bootstrap script (after the engine `<script>` tags) queries `.diagram-mermaid`, `.diagram-flow`, `.diagram-sequence` and calls the corresponding engine. Each call is wrapped in `try/catch`; on failure the node gets a `diagram-error` class and falls back to showing the raw source.

- **Why**: Matches the existing math bootstrap's defensive `try/catch` (`throwOnError: false` equivalent). Keeps per-engine wiring in one place.
- **Mermaid**: initialize with `startOnLoad:false` and call `mermaid.run`/`render`; pick `theme: 'dark'` vs `'default'` from `matchMedia('(prefers-color-scheme: dark)')`.
- **flowchart.js**: needs Raphael; parse with `flowchart.parse(src).drawSVG(el)`.
- **js-sequence-diagrams**: needs underscore + Raphael; render via `Diagram.parse(src).drawSVG(el, {theme:'simple'})`.

### Decision: Vendor engine assets as committed files under Resources
Download/commit minified builds of Mermaid, flowchart.js (+ Raphael), and js-sequence-diagrams (+ underscore) into `Sources/MD2Core/Resources/diagrams/`, declared in `Package.swift` `resources:`. Shared deps (Raphael) are included once.

- **Why**: Same delivery model as `katex/`; guarantees offline and reproducible builds.
- **Trade-off**: Increases bundle size meaningfully (Mermaid is large). Accepted as the cost of offline parity; documented in Risks.

## Risks / Trade-offs

- **Bundle size grows substantially (Mermaid is ~MBs minified)** → Inline only at preview-build time (already how math works); document the size increase; consider lazy-injecting an engine's `<script>` only when a document actually contains that diagram type, to keep the common-case preview small.
- **Engine load/parse cost on large documents** → Bootstrap runs once after load and only over matched nodes; engines render asynchronously. Keep the math and diagram bootstraps independent so one failing engine cannot stop the other.
- **Dark-mode theming differs per engine** → Mermaid has a dark theme; flowchart.js/js-sequence-diagrams are styled via options/CSS. Provide CSS overrides so diagram text inherits `--text` where the engine emits selectable text, accepting that fixed-palette SVG output may not perfectly match the theme.
- **Three engines pulling overlapping globals (Raphael, underscore)** → Load shared deps once, in dependency order, before the engines that need them; verify globals exist before invoking (guard like the math bootstrap's `typeof katex === "undefined"` check).
- **Mermaid version/API drift** → Pin a specific vendored version; record it so future updates are deliberate.

## Open Questions

- Should each engine's script be inlined unconditionally, or only when the document contains that diagram type (to cut preview size)? Leaning toward conditional injection for Mermaid given its size; resolve during implementation.
- Exact pinned versions of Mermaid / flowchart.js / Raphael / js-sequence-diagrams / underscore to vendor.
