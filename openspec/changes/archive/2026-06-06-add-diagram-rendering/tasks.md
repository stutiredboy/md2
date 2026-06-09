## 1. Vendor engine assets

- [x] 1.1 Create `Sources/MD2Core/Resources/diagrams/` and vendor pinned minified builds: `mermaid.min.js`, `flowchart.min.js`, `raphael.min.js`, `sequence-diagram.min.js`, `underscore.min.js`
- [x] 1.2 Record the pinned version of each vendored engine (comment header or a `VERSIONS` note) so future updates are deliberate
- [x] 1.3 Declare the `diagrams/` resource directory in `Package.swift` (`resources:` for the `MD2Core` target, alongside `katex/`)

## 2. Asset loader

- [x] 2.1 Add `DiagramAssets` enum (mirroring `MathAssets`) that loads each vendored JS file from `Bundle.module` subdirectory `diagrams`, returning `""` on failure
- [x] 2.2 Expose `mermaid`, `flowchart`, `raphael`, `sequence`, and `underscore` string properties in dependency order

## 3. Renderer block detection

- [x] 3.1 In `MarkdownRenderer`, intercept fenced blocks whose lower-cased info string is `mermaid`, `flow`, or `sequence` before normal code-block emission
- [x] 3.2 Emit a placeholder element per engine carrying the HTML-escaped raw source as text content (e.g. `<div class="diagram diagram-mermaid">…</div>`), mirroring `mathDisplayHTML`
- [x] 3.3 Ensure all other (and empty) info strings still flow through `fencedCodeBlock` to syntax-highlighted/plain code unchanged

## 4. HTML/script injection & bootstrap

- [x] 4.1 Inline the diagram engine scripts into the preview document in dependency order (raphael/underscore before flowchart.js/js-sequence-diagrams; mermaid standalone)
- [x] 4.2 Add a bootstrap script that queries `.diagram-mermaid`, `.diagram-flow`, `.diagram-sequence` and renders each via its engine, guarding for `typeof <engine> === "undefined"`
- [x] 4.3 Initialize Mermaid with `startOnLoad:false` and select dark vs default theme from `prefers-color-scheme`
- [x] 4.4 Wrap each render in `try/catch`; on failure add a `diagram-error` class and fall back to showing the raw source, keeping the math bootstrap independent

## 5. Styling

- [x] 5.1 Add CSS for `.diagram` (centering, spacing, overflow) and `.diagram-error` (monospace error styling like `.math-error`)
- [x] 5.2 Add light/dark overrides so diagram text/connectors contrast against the preview background

## 6. Tests

- [x] 6.1 Add `MD2Core` tests asserting `mermaid`/`flow`/`sequence` fences emit the correct `.diagram-*` placeholder with verbatim escaped source
- [x] 6.2 Add tests asserting non-diagram fences (e.g. `swift`, `text`, empty) still render as code blocks with no diagram placeholder
- [x] 6.3 Run `swift test` (41 tests pass); verified a 3-diagram sample renders all three types to SVG end-to-end in a real browser (Mermaid + flowchart.js + js-sequence-diagrams). The GUI `Scripts/functional_test.sh` drives the app via AppleScript and must be run interactively by the user.

## 7. Documentation

- [x] 7.1 Update `Docs/MarkdownSupport.md` with the supported diagram fence languages
- [x] 7.2 Update the feature lists in `README.md` and `README.zh-CN.md` to mention offline diagram rendering
