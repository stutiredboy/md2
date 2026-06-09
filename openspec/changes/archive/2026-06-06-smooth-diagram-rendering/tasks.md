## 1. Placeholder markup & styling

- [x] 1.1 In `MarkdownRenderer.diagramHTML(kind:source:)`, emit the placeholder in a "pending" state that keeps the verbatim source machine-readable but not shown as visible text (e.g. add a `diagram-pending` class; keep source as `textContent` per design Decision 1A).
- [x] 1.2 Add CSS in `htmlDocument` so `.diagram-pending` hides its text content (collapsed/transparent) and a revealed state (`.diagram-ready`) shows content with a short opacity transition (~120ms).
- [x] 1.3 Add a small `min-height` to a pending diagram to dampen the layout jump when the SVG arrives (design Decision 3); keep it modest.

## 2. Bootstrap reveal logic

- [x] 2.1 In `diagramBootstrap`, after a synchronous engine (`flow`, `sequence`) draws its SVG, mark the element revealed (`diagram-ready`).
- [x] 2.2 In the mermaid `.then` callback, mark the element revealed after `innerHTML` is set.
- [x] 2.3 In the `fail()` path, reveal the element (it sets `textContent`/`diagram-error`) so a malformed diagram shows its source, never blank.
- [x] 2.4 Ensure a diagram whose engine is unavailable still ends up revealed (guard so it shows its source rather than staying hidden).

## 3. Tests

- [x] 3.1 Update/extend `DiagramRenderingTests` to assert the emitted placeholder is in the pending (source-hidden) state and carries the verbatim source.
- [x] 3.2 Assert the bootstrap contains reveal logic for each engine and for the error/fallback path.
- [x] 3.3 Confirm existing diagram engine-inlining and render assertions still pass.

## 4. Manual verification

- [x] 4.1 Preview `Examples/Sample.md`: confirm diagram blocks no longer flash raw source then swap; they fade in once rendered.
- [x] 4.2 Confirm a malformed diagram still shows its source/error (not blank).
- [x] 4.3 Toggle Write↔Read a few times and confirm no raw-source flash on subsequent renders.
- [x] 4.4 `swift build` succeeds and `swift test` passes.

## 5. Optional (may defer)

- [x] 5.1 Evaluate keeping the preview `WKWebView` alive across mode switches so engines render once (design Decision 4); implement only if the fade alone is insufficient and it does not regress fragment-based scroll positioning.
