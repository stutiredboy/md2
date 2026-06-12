## Why

Task lists (`- [ ]` / `- [x]`) render in the preview as disabled checkboxes — purely decorative. Checking off an item means switching to edit mode, finding the line, and editing the marker by hand. Making the checkboxes clickable in preview mode turns rendered to-do lists into live, usable checklists: click to toggle, and the Markdown source updates itself.

## What Changes

- Task-list checkboxes in the preview become enabled and clickable (cursor feedback included); all other rendered content stays read-only.
- Each rendered task checkbox carries the 1-based source line of its list item (a new `data-md2-task-line` attribute), so a click can be mapped back to the exact Markdown line — including items nested in sublists and inside blockquotes.
- Clicking a checkbox flips the `[ ]` / `[x]` marker on that source line in the document text. The edit flows through the normal document pipeline: re-render, dirty flag, and the existing autosave behavior.
- The preview keeps its scroll position across the toggle-triggered re-render, reusing the existing viewport-anchor restore machinery (no jump back to top).
- Stale or invalid clicks (line no longer a task item, out of range) are ignored safely rather than corrupting unrelated lines.

## Capabilities

### New Capabilities

- `preview-task-toggle`: Clicking a task-list checkbox in preview mode toggles the corresponding `[ ]`/`[x]` marker in the Markdown source, preserving scroll position and routing the edit through the standard document update/autosave pipeline.

### Modified Capabilities

- `list-rendering`: The "Task list and mixed-kind nesting preservation" requirement changes — task checkboxes are no longer rendered `disabled`; they render enabled and carry source-line metadata identifying the originating Markdown line.

## Impact

- `Sources/MD2Core/MarkdownRenderer.swift` — `ListItem` gains per-item source-line tracking; `listBlock`/`buildList` thread line numbers (including the blockquote `lineOffset`); checkbox HTML drops `disabled` and gains `data-md2-task-line`; task-list CSS gets pointer cursor.
- `Sources/MD2App/MarkdownPreviewView.swift` — injected user script gains a checkbox click listener posting `{line, checked}` via a new `toggleTask` script message handler; `Coordinator` forwards it to a new `onToggleTask` callback.
- `Sources/MD2App/ContentView.swift` — wires `onToggleTask` to the document store, capturing the live preview viewport anchor first so the reloaded page restores scroll position.
- `Sources/MD2App/DocumentStore.swift` — new `toggleTask(atLine:to:)` mutation that validates the target line and rewrites the marker; existing `text.didSet` handles re-render/dirty/autosave.
- Tests in `Tests/MD2CoreTests/` — renderer attribute/enabled-state coverage (`MarkdownRendererTests`, `SourceLineMetadataTests`) and `DocumentStoreTests` for the toggle mutation.
- No new dependencies; no changes to the on-disk document format.
