## Why

Markdown2 currently has no in-document search. Readers and writers must scan
manually to locate text, which is painful in long documents. Pressing ⌘F — the
universal "find" gesture on macOS — does nothing today. We need find in both
edit and preview modes, plus replace while editing.

## What Changes

- Pressing **⌘F** opens a find affordance in the active mode:
  - **Edit mode**: a find/replace bar that searches the source text, navigates
    between matches, and can replace the current match or all matches.
  - **Preview mode**: a find-only bar that searches the rendered page and
    navigates between matches (no replace — the rendered HTML is read-only).
- **⌘G / ⇧⌘G** move to the next / previous match while the find bar is open.
- **Esc** (or the bar's close control) dismisses the find bar and returns focus
  to the document.
- The find bar reports match position (e.g. "2 of 7") and indicates when a query
  has no matches.
- A new **Edit** menu (or Find submenu) exposes Find, Find Next, Find Previous,
  and (in edit context) Replace, each with its standard shortcut.

## Capabilities

### New Capabilities
- `document-find`: In-document text search in edit and preview modes —
  invocation, match navigation, match status reporting, and (edit mode only)
  find-and-replace.

### Modified Capabilities
<!-- No existing spec's requirements change. -->

## Impact

- `Sources/MD2App/MD2App.swift`: add Edit/Find menu commands and shortcuts.
- `Sources/MD2App/ContentView.swift`: coordinate find invocation per mode and
  host the preview find bar.
- `Sources/MD2App/MarkdownEditorView.swift`: enable the source-text find/replace
  bar.
- `Sources/MD2App/MarkdownPreviewView.swift`: drive search in the web view and
  surface match navigation/status.
- `Sources/MD2App/DocumentStore.swift`: relay find invocation from menu commands
  to the focused window's view.
- `Sources/MD2App/AppSettings.swift`: add localized strings (EN / zh-Hans) for
  the find UI and menu items.
