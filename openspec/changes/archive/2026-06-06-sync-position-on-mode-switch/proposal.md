## Why

Switching between Write (editor) and Read (preview) modes always resets the viewport to the top of the document. On any document longer than a screen, the user loses their place and must scroll back to where they were working — a constant, jarring interruption to the read/edit loop.

## What Changes

- When switching **Write → Read**, the preview SHALL scroll so the content the user was viewing/editing in the editor stays in view, anchored to the nearest section heading at or above that point.
- When switching **Read → Write**, the editor SHALL scroll so the source for the section the user was reading stays in view, anchored to the same heading.
- Position is mapped through the document outline (each `Heading` already carries both its source `line` and its HTML element `id`), which bridges the editor's line coordinate space and the preview's DOM/scroll coordinate space.
- Anchoring is section/heading granularity by design — the goal is "land in the same part of the document," not pixel- or cursor-exact alignment.
- Documents with no headings, or content above the first heading, SHALL fall back to a best-effort proportional (scroll-fraction) position so the viewport still tracks roughly, never silently jumping to the top.

## Capabilities

### New Capabilities
- `mode-switch-position-sync`: Preserving the user's reading/editing position across Write↔Read mode switches by anchoring the destination viewport to the document location they were at in the source mode.

### Modified Capabilities
<!-- None: math-rendering and diagram-rendering specs are unaffected. -->

## Impact

- `Sources/MD2App/ContentView.swift` — owns `mode`; must capture the current position from the outgoing view and hand a target to the incoming view on switch.
- `Sources/MD2App/MarkdownEditorView.swift` — must expose the editor's current top/cursor line, and accept a target line to scroll to on appear (extends existing `jumpLine` scroll logic).
- `Sources/MD2App/MarkdownPreviewView.swift` — must report the heading currently at the top of the WebView viewport (via JavaScript), and accept a target heading id to scroll to (extends existing `jumpHeadingID` logic).
- `Sources/MD2App/DocumentStore.swift` and/or new lightweight state — coordinates the captured position; reuses `jumpLine` / `jumpHeadingID` channels where possible.
- `Sources/MD2Core/OutlineBuilder.swift` / `Heading` — read-only; the existing `line`↔`id` mapping is the anchor source. No requirement change.
- No new dependencies; all logic is local (AppKit/WebKit), no network.
