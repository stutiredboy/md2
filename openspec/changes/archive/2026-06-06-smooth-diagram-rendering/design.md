## Context

Diagrams are emitted by `MarkdownRenderer.diagramHTML(kind:source:)` as:

```html
<div class="diagram diagram-mermaid">RAW SOURCE TEXT</div>
```

The raw source is the element's visible text content. `diagramBootstrap` (an inline `<script>` at the end of `<body>`) later reads `el.textContent` and renders:

- **flow / sequence**: synchronous — `el.textContent = ""` then `engine.parse(source).drawSVG(el)`.
- **mermaid**: asynchronous — `mermaid.render(...).then(result => el.innerHTML = result.svg)`.

Diagnostics from the `sync-position-on-mode-switch` work showed the page's `scrollHeight` was already final at load, yet a visible flash occurred ~1s later: the Mermaid promise resolving and swapping visible raw source for the SVG. The synchronous engines swap sooner but still show source for the brief window between parse and bootstrap execution. Because the preview `WKWebView` is recreated on every Write↔Read switch, every toggle re-runs the engines and re-flashes.

Constraints: rendering must stay fully offline (bundled assets, no network); the existing error fallback (show raw source / inline error on parse failure) must be preserved; the engine still needs the verbatim source from the DOM.

## Goals / Non-Goals

**Goals:**
- A diagram block never shows its raw source as normal text while waiting to render.
- The transition from "loading" to rendered SVG is smooth (no abrupt source→diagram swap).
- Preserve offline rendering and the error fallback exactly.
- Reduce layout shift from placeholder → final SVG where practical.

**Non-Goals:**
- Pre-computing diagram sizes or server-side diagram rendering.
- Changing which info strings are diagrams or how engines parse.
- Eliminating all layout movement (final SVG size is only known after render).

## Decisions

### Decision 1: Hide the source in the placeholder, keep it machine-readable
Keep the verbatim source in the DOM for the engine, but do not render it as visible text. Two viable encodings:

- **(A) CSS-hide the text**: keep `el.textContent` as the source but make `.diagram` visually empty until rendered (e.g. a `diagram-pending` state with `color: transparent`/`font-size: 0`, or `visibility: hidden`). The bootstrap reads `textContent` unchanged, then adds a `diagram-ready` class to reveal.
- **(B) Move source to an attribute**: emit the source in a `data-source` attribute (or a hidden child) and render a small neutral placeholder. The bootstrap reads `data-source`.

Chosen: **(A)** — smallest change, keeps the bootstrap's `el.textContent` contract and the error path (which sets `textContent = source`) working with minimal edits. `data-source` (B) is cleaner conceptually but touches both the emit and every engine read; revisit only if (A) proves awkward.

### Decision 2: Reveal with a short fade once rendered
Add a `diagram-ready` (or reveal) class after the engine populates the element, with a brief CSS opacity transition (~120–150ms). This turns the swap into a gentle fade rather than a hard flip. For the synchronous engines, set it right after `drawSVG`; for mermaid, inside the `.then`. On error, the existing `fail()` adds `diagram-error` and sets `textContent` — that path must also reveal (show the source/error), so `fail()` reveals too.

### Decision 3: Reserve a small min-height to dampen shift
Give a pending diagram a modest `min-height` so the page does not jump from ~0 to the SVG height in one step. The final SVG height still settles the layout, but the initial reservation reduces the visible jump. Keep it small (e.g. a few `em`) to avoid large empty gaps for tiny diagrams.

### Decision 4 (optional, may defer): Keep the preview WebView alive across mode switches
The flash recurs on every toggle because the `WKWebView` is recreated and re-renders. An alternative is to keep one preview web view alive (render once) and show/hide it rather than destroy it on each switch. This removes per-toggle re-rendering entirely but is a larger change to `editorSurface`/view lifetime and interacts with the fragment-based scroll positioning from `sync-position-on-mode-switch`. Treat as a separate, optional follow-up; Decisions 1–3 already remove the *visible* flash on first and subsequent renders.

## Risks / Trade-offs

- **Hidden text still measured for layout** → With CSS `visibility: hidden` the source text still occupies space (shift on reveal). Mitigate by collapsing the text (`font-size: 0`/`height: 0` on the pending inner text) or using `data-source` (Decision 1B) if shift is objectionable.
- **Error path left hidden** → If `fail()` forgets to reveal, a malformed diagram would render blank instead of showing source. Mitigate: `fail()` must add the reveal class; add a test for the error path remaining visible.
- **Reveal class never added if an engine script is missing** → Guard so a diagram with no available engine still reveals its source rather than staying blank.
- **Fade adds perceived latency** → Keep the transition short (~120ms) so it reads as smooth, not slow.

## Open Questions

- Is a small `min-height` reservation worth the occasional empty gap for tiny diagrams, or should we skip Decision 3 and accept the height settle?
- Should the optional Decision 4 (persistent preview web view) be pursued now or genuinely deferred? Leaning defer.
