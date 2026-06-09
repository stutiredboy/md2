## Context

Mode is a plain `@State var mode: EditorMode` in `ContentView`. The `editorSurface` `@ViewBuilder` swaps between `MarkdownEditorView` (an `NSScrollView` + `NSTextView`) and `MarkdownPreviewView` (a `WKWebView`) based on `mode`. Each switch tears down one `NSViewRepresentable` and builds the other from scratch, so the destination view always starts at scroll offset zero.

Two coordinate spaces are involved:
- **Editor**: source text lines (1-based), driven via the existing `@Binding var jumpLine: Int?` and `scroll(to:in:)` in `MarkdownEditorView`.
- **Preview**: DOM elements / pixel scroll, driven via the existing `@Binding var jumpHeadingID: String?` and `scrollIntoView` in `MarkdownPreviewView`.

The bridge between them already exists: `document.rendered.outline` is `[Heading]`, and each `Heading` carries both `line` (source line) and `id` (the `id` attribute emitted on the `<h*>` element). The outline sidebar already uses this exact pairing to jump both views (`DocumentStore.jump(to:)`).

Constraint: `WKWebView` scroll position can only be read asynchronously via `evaluateJavaScript` (completion handler). The capture-on-leave must therefore tolerate async; we capture position *before* the view is torn down, store it, then apply it after the destination view mounts.

## Goals / Non-Goals

**Goals:**
- On every Write↔Read switch, land the destination viewport in the same section the user was in.
- Reuse the existing `jumpLine` / `jumpHeadingID` scroll channels rather than inventing parallel scrolling code.
- Keep anchoring logic in `MD2Core` where it is unit-testable (line↔heading resolution is pure).
- Graceful fallback (proportional scroll) when no heading anchor exists.

**Non-Goals:**
- Pixel-exact or cursor-exact alignment between modes.
- Bidirectional live scroll-sync while both views are visible (there is only ever one visible).
- Preserving horizontal scroll, text selection, or cursor column.

## Decisions

### Decision 1: Anchor on the nearest preceding heading, mapped through the outline
For **Write → Read**: read the editor's current anchor line (top visible line, see Decision 3), find the last `Heading` whose `line <= anchorLine`, and scroll the preview to that heading's `id`.

For **Read → Write**: ask the WebView (via JS) which heading element is at/above the top of the viewport, get its `id`, find the matching `Heading`, and scroll the editor to its `line`.

Rationale: the outline pairing is already the app's canonical cross-mode mapping and is exactly section granularity, matching the requirement. Alternative considered — mapping every source line to a DOM pixel offset (a full source-map) — is far more complex, brittle against the renderer's block coalescing, and unnecessary for section-level fidelity.

### Decision 2: A small shared "pending anchor" rather than overloading semantics of jumpLine/jumpHeadingID
Introduce a lightweight value capturing the cross-mode target, e.g.:

```
enum ModeSwitchAnchor {
    case heading(id: String)      // for the preview
    case line(Int)                // for the editor
    case fraction(Double)         // fallback for either
}
```

`ContentView` captures the anchor from the outgoing view at the moment of switch and applies it to the incoming view on mount. Implementation can route through the existing `document.jumpLine` / `document.jumpHeadingID` bindings (preview/editor already consume these and self-clear them), adding a `jumpFraction` channel for the fallback. The outline-sidebar jump path keeps working unchanged because it sets the same channels.

Rationale: reuses proven scroll application code; avoids a second scrolling mechanism. Alternative — a brand new binding pair dedicated to mode switches — duplicates the self-clearing scroll plumbing already present.

### Decision 3: Capturing the editor anchor line = top visible line, not the cursor
Capture the source line at the **top of the editor's visible rect**, computed from the `NSScrollView` `contentView.bounds.origin.y` via the layout manager (`glyphIndex(for:)` → character index → line number). The cursor may be off-screen; the top visible line is what the user perceives as "where I am."

Rationale: matches user expectation ("keep my page"). The cursor line is a reasonable secondary fallback if layout query fails. This computation belongs to `MarkdownEditorView` (needs the live `NSTextView`/layout manager), exposing the result up to `ContentView` via a callback or a binding updated on switch.

### Decision 4: Capturing the preview anchor = first heading at/above viewport top, via JS
Inject/evaluate JavaScript that walks `document.querySelectorAll('h1,h2,h3,h4,h5,h6')`, finds the last one whose `getBoundingClientRect().top <= threshold` (small positive threshold, e.g. a few px), and returns its `id`. If none qualify (scrolled above the first heading, or no headings), return the scroll fraction `scrollY / (scrollHeight - innerHeight)` instead.

Because `evaluateJavaScript` is async, `ContentView` cannot synchronously read this during the SwiftUI state change. Approach: the preview view continuously (or on a debounced scroll handler) reports its current top-heading id / fraction back up via a callback, so the latest known anchor is already available the instant the user toggles mode. Capturing on scroll also keeps the cost off the switch path.

### Decision 5: Pure resolution helpers live in MD2Core
Add pure functions (unit-tested, no AppKit) such as:
- `Outline.heading(atOrAbove line: Int) -> Heading?`
- `Outline.heading(forID id: String) -> Heading?`
- line ↔ fraction helpers given total line count.

Rationale: keeps `ContentView` thin and makes the section-mapping logic testable without a running WebView or text view (which the test target cannot host).

## Risks / Trade-offs

- **Async preview scroll read races the teardown** → Mitigate by reporting the preview's top heading continuously on scroll (Decision 4), so the value is cached before the switch, not fetched during it.
- **`scrollIntoView` runs before the WebView finishes (re)laying out** → The preview is reused/reloaded; reuse the existing `DispatchQueue.main.async` deferral already in `updateNSView`, and only scroll once content load is complete (guard on the existing `lastHTML` load path).
- **Editor top-visible-line query returns nothing for an empty/zero-height layout** → Fall back to cursor line, then to fraction 0.
- **Heading ids are de-duplicated with numeric suffixes** (`Slugger.uniqueSlug`) → Always resolve ids through the same `outline` array used to render, so captured id and target id come from one source of truth; never re-slug independently.
- **Renderer coalesces blocks / blockquotes recompute outlines** → Anchoring only at top-level headings (the outline) avoids dependence on inner-block structure; acceptable per heading-granularity requirement.
- **Over-scroll near document end** (heading near bottom can't reach viewport top) → Acceptable; browser/`scrollIntoView` clamps. Section is still visible, satisfying the spec.

## Open Questions

- Should the preview anchor be captured on a debounced scroll callback, or lazily snapshotted just before switch via a synchronous-ish path? Leaning debounced-on-scroll (Decision 4) for simplicity and to avoid async-on-switch.
- Do we also preserve position across document reloads/autosave re-render? Out of scope here; this change targets only mode switches.
