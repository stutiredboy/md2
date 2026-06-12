## 1. Renderer: per-item source lines and interactive checkboxes (MD2Core)

- [x] 1.1 Add a `line: Int` field to `ListItem` and populate it in `listBlock` (absolute 1-based line: `lineOffset + index + 1`); thread the existing `lineOffset` parameter from `renderBody` into `listBlock` so blockquote-nested lists stay absolute
- [x] 1.2 In `buildList`, render task checkboxes without `disabled` and with `data-md2-task-line="<line>"` on the `<input>`
- [x] 1.3 Add `cursor: pointer` to the `.task-list input` rule in the inline stylesheet
- [x] 1.4 Renderer tests: checkbox is enabled and carries the correct `data-md2-task-line` for top-level, nested, and blockquote-nested task items; non-task lists unaffected (extend `MarkdownRendererTests` / `SourceLineMetadataTests`)

## 2. Document mutation (MD2App)

- [x] 2.1 Add `DocumentStore.toggleTask(atLine:to:)`: split text with the renderer's line normalization, bounds-check, locate the task marker (`[ ]`/`[x]`/`[X]` after a `-`/`*`/`+` bullet, skipping leading whitespace and `>` prefixes), rewrite only the marker to the requested absolute state, reassemble text; ignore anything that fails validation
- [x] 2.2 `DocumentStoreTests`: check/uncheck round-trip, uppercase `[X]`, nested and blockquoted lines, idempotent duplicate requests, out-of-range and non-task lines leave text unchanged, dirty flag set on a successful toggle

## 3. Preview wiring (MD2App)

- [x] 3.1 In `MarkdownPreviewView`'s user script, add a delegated `click` listener for `input[type=checkbox][data-md2-task-line]` that lets the checkbox toggle visually and posts `{line, checked}` on a new `toggleTask` message handler
- [x] 3.2 Register the `toggleTask` handler, decode the payload in `Coordinator.userContentController`, and forward to a new `onToggleTask(line:checked:)` callback (default no-op, kept current in `updateNSView` like the other callbacks)
- [x] 3.3 In `ContentView`, wire `onToggleTask`: capture the live anchor via `previewViewport.currentAnchor`, then call `document.toggleTask(atLine:to:)` and set `document.previewJumpAnchor` to the captured anchor so the reloaded preview restores scroll position

## 4. Verification

- [x] 4.1 Run `swift test` and make the full suite pass
- [x] 4.2 Manual check in the running app: toggle top-level, nested, and blockquoted tasks; confirm marker updates in edit mode, scroll position holds deep in a long document, dirty indicator (`*`) appears, and autosave writes the file
