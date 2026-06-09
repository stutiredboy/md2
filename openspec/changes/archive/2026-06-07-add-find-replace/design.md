## Context

Markdown2 presents a document in two mutually-exclusive surfaces inside
`ContentView`:

- **Edit mode** — `MarkdownEditorView`, an `NSViewRepresentable` wrapping an
  `NSTextView` in an `NSScrollView`. It edits the raw markdown source.
- **Preview mode** — `MarkdownPreviewView`, an `NSViewRepresentable` wrapping a
  `WKWebView` showing rendered, read-only HTML.

These are completely different native views, so "find" has to be implemented
differently in each. Menu commands currently reach the focused window through
`MD2AppDelegate.currentDocumentStore` (see how Save is wired in `MD2App.swift`).
Localized strings flow through `AppSettings.text(_:)` / `L10nKey` (EN + zh-Hans).

`NSTextView` exposes the source text and selection APIs needed for a custom,
localized **find/replace bar** (find, replace current/all, wrap-around, match
navigation). `WKWebView` exposes a native
`find(_:configuration:completionHandler:)` API (macOS 11+) that highlights and
scrolls to matches but provides **no UI** and does not expose the total/current
match position the spec requires — the preview UI and count reporting are ours
to build.

## Goals / Non-Goals

**Goals:**
- ⌘F opens find in whichever mode is active.
- Edit mode supports find **and** replace (replace one / replace all).
- Preview mode supports find only (rendered HTML is read-only).
- Match navigation (next/previous, ⌘G / ⇧⌘G) and a visible match status.
- Esc / close button dismisses the bar and restores focus to the document.
- Localized UI (EN / zh-Hans) consistent with the rest of the app.

**Non-Goals:**
- Find/replace across multiple open documents or project-wide search.
- Regex-only custom UI (the native edit find bar already offers its built-in
  modes; the preview bar stays plain-substring).
- Replace in preview mode.
- Persisting search history between launches.

## Decisions

### Decision 1: Use a custom SwiftUI find/replace bar for edit mode
The source editor hosts a compact SwiftUI find/replace bar from `ContentView`.
`MarkdownEditorView` drives the underlying `NSTextView` directly: it computes
case-insensitive matches, applies temporary highlights, scrolls the current match
into view, and performs replace-current / replace-all edits against the text
view so normal dirty-state propagation still runs.

- **Why:** In practice the native text finder can be preempted by default menu
  routing and gives weak feedback in this app's styled editor. A custom bar gives
  the same visible status contract as preview mode ("2 of 7" / no results),
  obvious highlights, and deterministic replace behavior.
- **Alternatives considered:** `NSTextView`'s built-in find bar via
  `performTextFinderAction(_:)`. Rejected for v1 because it did not reliably
  provide visible, spec-aligned feedback in the app shell.

### Decision 2: Custom lightweight find bar for preview mode
Preview mode gets a small SwiftUI find bar hosted by `ContentView`, shown only
when find is invoked in `.read` mode. It drives the web view through injected
JavaScript helpers that walk visible text nodes, wrap case-insensitive matches in
`<mark>` elements, scroll the current mark into view, and return `{total, index}`
for the status label.

- **Why:** `WKWebView.find` can locate and highlight a match, but it cannot
  report "2 of 7". The custom helper supplies the count/index contract while
  keeping preview read-only.
- **Alternatives considered:** `WKWebView.find(_:configuration:)`. Rejected for
  v1 because its result only reports whether a match was found, which is
  insufficient for the required status label.

### Decision 3: Route ⌘F through the focused `DocumentStore`, dispatch by mode
Add a menu **Edit/Find** command group in `MD2App.swift`. Its actions call
`appDelegate.currentDocumentStore` (the existing pattern) to set a published
*find invocation token* (e.g. `findCommand: FindCommand?` where `FindCommand` is
`.show / .next / .previous / .replace`). `ContentView` observes that token and,
based on its local `mode`, forwards it to the active surface:
- `.write` → a binding into `MarkdownEditorView` that calls the text view's find
  actions.
- `.read` → toggles/updates the SwiftUI preview find bar.

- **Why:** Mirrors how Save already crosses the SwiftUI↔AppKit boundary, so a
  single menu shortcut works correctly per window and per mode without fragile
  global key monitors.
- **Alternatives considered:** `NSEvent` local key monitor, or `FocusedValues`.
  Rejected: the store-token pattern is already established and window-scoped.

### Decision 4: Mode switch / document change closes find
Switching modes or loading a new document dismisses any open find bar to avoid a
stale bar pointing at the wrong surface. The native edit find bar closes when
the editor view is torn down on mode switch; the preview bar is dismissed
explicitly in `ContentView` when `mode` or `documentIdentity` changes.

## Risks / Trade-offs

- **Find shortcut/menu conflicts with AppKit/WebKit defaults** → Mitigation:
  editor and preview native views intercept standard find key/menu actions and
  relay them to `ContentView`, preventing the default native bars from stealing
  the workflow.
- **Esc collision in edit mode** — the editor currently maps Esc to "switch to
  preview". → Mitigation: the SwiftUI find bar consumes Esc while focused and
  closes itself; only when focus is back in the editor does Esc fall through to
  the existing preview switch.
- **Injected find script lifecycle** across preview reloads → Mitigation: queue
  the latest query while the page is loading and re-run it in `didFinish`, so a
  same-query search never targets the previous DOM.
- **Anchor/scroll machinery interaction** — programmatic find-scrolling in the
  preview must not be mis-captured as the user's mode-switch anchor →
  Mitigation: rely on the existing scroll-suppression hooks or ignore anchor
  reports while the find bar drives scrolling.

## Open Questions

- Should the edit and preview bars share one generic component? Current decision:
  keep separate small views because edit mode has replacement controls and
  preview mode is find-only.
- Should case-sensitivity / whole-word toggles appear in the preview bar, or is
  case-insensitive substring enough for v1? Current default: case-insensitive,
  wrap-around, no extra toggles.
