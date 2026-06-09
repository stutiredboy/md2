## Why

In Read-mode preview, diagram blocks (Mermaid, flowchart.js, sequence) render asynchronously via their JavaScript engines. Until each engine resolves, the preview shows the block's **raw source text**; the engine then swaps it for the rendered SVG. For Mermaid this swap can land a second or more after the page loads, producing a visible "flash" — raw code appearing and then abruptly becoming a diagram. Because every Write↔Read switch recreates the preview from scratch, this flash recurs on every toggle, not just the first render. It was surfaced during the `sync-position-on-mode-switch` work and is a distinct rendering concern.

## What Changes

- The rendered diagram placeholder SHALL NOT display its raw source text while waiting for the engine; the source is preserved for the engine to read but is not shown to the reader.
- Each diagram block SHALL transition smoothly to its rendered SVG (no abrupt source→diagram swap), e.g. via a hidden-until-rendered state with a short reveal.
- On a parse/render error the raw source SHALL still be shown (current error behavior preserved), so a failed diagram is never silently blank.
- Layout shift from the placeholder resolving to its final SVG height SHALL be reduced where practical.
- Investigate (in design) whether keeping the preview `WKWebView` alive across mode switches is worthwhile so engines render once instead of on every toggle. This is optional and may be deferred.

## Capabilities

### New Capabilities
- `diagram-render-smoothing`: How diagram blocks present themselves between page load and engine completion — hiding raw source, revealing the rendered SVG without a jarring flash, while preserving offline rendering and error fallback.

### Modified Capabilities
- `diagram-rendering`: The existing offline diagram capability gains a requirement governing the loading/transition appearance of a diagram block (placeholder must not flash raw source). Existing rendering and error-fallback behavior is unchanged.

## Impact

- `Sources/MD2Core/MarkdownRenderer.swift` — `diagramHTML(kind:source:)` (placeholder markup), the diagram CSS in `htmlDocument`, and `diagramBootstrap` (reveal logic; error path keeps showing source).
- `Tests/MD2CoreTests/DiagramRenderingTests.swift` — assert the placeholder hides source until rendered and that the engines/bootstrap are still wired.
- Possibly `Sources/MD2App/MarkdownPreviewView.swift` / `ContentView.swift` if the optional "keep WebView alive across switches" path is pursued.
- No new runtime dependencies; rendering stays fully offline.
