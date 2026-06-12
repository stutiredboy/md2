## Context

Task list items (`- [ ]` / `- [x]`) currently render as `<input type="checkbox" disabled>` in `MarkdownRenderer.buildList` (Sources/MD2Core/MarkdownRenderer.swift:469). The preview is a `WKWebView` (`MarkdownPreviewView`) that loads fully re-rendered HTML on every text change; native ↔ page communication already exists in both directions (script message handlers `enterEdit` / `anchorChange` to native, `evaluateJavaScript` to the page). Every top-level block carries `data-md2-source-line` / `data-md2-source-end-line` attributes, but individual `<li>` items do not — the parser is line-based, so each list item corresponds to exactly one source line.

`DocumentStore.text` is the single source of truth: its `didSet` re-renders, marks the document dirty, and schedules autosave. Any preview-initiated edit must flow through it.

## Goals / Non-Goals

**Goals:**
- One-click toggling of task items in preview mode, writing the change back to the Markdown source.
- Works for nested task items and task items inside blockquotes.
- Preview keeps its scroll position across the resulting re-render.
- The edit behaves exactly like a typed edit: dirty flag, autosave, undo-irrelevant (preview has no undo stack).

**Non-Goals:**
- No other interactive editing in the preview (text, headings, tables stay read-only).
- No partial/incremental DOM patching of the preview — the full re-render pipeline stays as is.
- No new task-list syntax (e.g. `* [ ]`, `+ [ ]` already parse via existing bullet handling; ordered-list checkboxes remain unsupported, matching the parser).
- No toggling from the editor surface (already trivially editable there).

## Decisions

### 1. Per-item source line via a `data-md2-task-line` attribute on the `<input>`

`ListItem` gains a `line: Int` field. `listBlock` consumes one line per item, so the absolute 1-based line is `lineOffset + index + 1`; `listBlock` gains the same `lineOffset` parameter `renderBody` already threads to blockquotes, keeping lines absolute for nested renders. The attribute goes on the checkbox input itself (not the `<li>`), so the click handler reads it directly from `event.target`.

*Alternative considered:* deriving the line in JS from the enclosing block's `data-md2-source-line` plus the item's index. Rejected — blank lines inside list runs and nested-item flattening make that mapping fragile; the renderer knows the exact line for free.

### 2. Click → script message → native mutation (page DOM is never authoritative)

The injected user script adds a delegated `click` listener for `input[type=checkbox][data-md2-task-line]`, lets the native checkbox toggle visually (optimistic, no flash), and posts `{line, checked}` on a new `toggleTask` message handler. The `Coordinator` forwards to an `onToggleTask(line:checked:)` callback wired in `ContentView` to `DocumentStore`.

The message carries the **desired state** (`checked`), not a "flip" command: if the page were ever stale, applying an absolute state is idempotent and converges, while a blind flip could invert the wrong way.

### 3. `DocumentStore.toggleTask(atLine:to:)` validates before writing

The mutation splits `text` using the same line normalization the renderer uses, bounds-checks the line, and verifies it actually contains a task marker (`[ ]`, `[x]`, `[X]` immediately after a `-`/`*`/`+` bullet, allowing leading whitespace and `>` blockquote prefixes). It rewrites only the marker character span and reassembles. Anything that does not validate is silently ignored — a stale or malformed message must never corrupt an unrelated line. Setting `text` triggers the existing render/dirty/autosave path unchanged.

### 4. Scroll preservation reuses the viewport-anchor machinery

The toggle handler in `ContentView` first captures the live anchor via `previewViewport.currentAnchor` (existing 0.25 s timeout-capped capture), then mutates the text and sets `document.previewJumpAnchor` so the reloaded page restores the position through the existing `__md2ScrollToViewportAnchor` pinning path.

*Alternative considered:* skipping the reload entirely by mutating text silently and patching the DOM. Rejected — it forks the "text is the single source of truth, HTML is derived" invariant for one feature, and the anchor-restore path already exists and is battle-tested for mode switches.

### 5. Cursor affordance via CSS only

`.task-list input { cursor: pointer; }` added to the inline stylesheet. No hover effects or hit-target enlargement in v1.

## Risks / Trade-offs

- [Full reload per click causes a brief repaint] → Anchor restore pins the viewport; the optimistic DOM toggle means the checkbox state never appears to lag. Documents heavy with math/diagrams re-run their engines, which is the same cost as any keystroke in edit mode — acceptable and consistent.
- [Anchor capture is async; a fast double-click could interleave] → Captures supersede each other (existing `pendingCaptureID` machinery) and the mutation applies absolute state, so the final state matches the last click.
- [Line numbers in a stale page mismatching current text] → Cannot happen in practice (preview is read-only, every text change reloads it), but the validate-before-write guard in Decision 3 covers it anyway.
- [`- [ ]` items inside blockquotes have `>` prefixes on the source line] → The marker-rewrite scanner skips `>` prefixes and whitespace before locating the bullet, mirroring how `blockquoteBlock` strips them for rendering.

## Open Questions

None — all behavior is determined by existing pipeline conventions.
