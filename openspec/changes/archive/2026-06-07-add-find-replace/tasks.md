## 1. Localization & shared types

- [x] 1.1 Add `L10nKey` cases for find UI: find label, replace, replace all, next, previous, close, match status ("%d of %d" / "no results"), and the Edit menu title — with EN and zh-Hans entries in `AppSettings.swift`.
- [x] 1.2 Define a `FindCommand` type (e.g. `.show`, `.next`, `.previous`) used to relay menu actions to the active surface.

## 2. Menu & command routing

- [x] 2.1 Add an Edit/Find command group in `MD2App.swift` with Find (⌘F), Find Next (⌘G), Find Previous (⇧⌘G); actions call `appDelegate.currentDocumentStore`. (Also added Find and Replace… ⌥⌘F so the native replace UI is reachable from the menu.)
- [x] 2.2 Add a published find-invocation token (`FindCommand?`) to `DocumentStore.swift` that menu actions set and `ContentView` observes.
- [x] 2.3 In `ContentView`, observe the token and dispatch to the active surface based on `mode`; reset the token after handling.

## 3. Edit-mode find/replace (custom find bar)

- [x] 3.1 In `ContentView`, host a custom SwiftUI edit-mode find/replace bar with query, replacement, previous/next, replace, replace-all, localized match status, and close controls. (`EditorFindBar.swift`)
- [x] 3.2 In `MarkdownEditorView`, drive search directly against the `NSTextView`: compute case-insensitive matches, apply temporary highlights, scroll the current match into view, and report index/total back to the bar.
- [x] 3.3 Intercept standard find key/menu actions in the editor text view so ⌘F / ⌘G / ⇧⌘G route to the custom bar instead of AppKit's native finder.
- [x] 3.4 Confirm replace and replace-all update the source text through the text view so `textDidChange` updates the binding and dirty state.

## 4. Preview-mode find bar (custom)

- [x] 4.1 Build a minimal SwiftUI find bar view (query field, prev/next buttons, match-count label, close button) using app localization. (`PreviewFindBar.swift`)
- [x] 4.2 Host the bar in `ContentView`, shown only in `.read` mode when find is invoked; focus the query field on show; dismiss on Esc/close.
- [x] 4.3 In `MarkdownPreviewView`, expose a way to drive search and report match index/total back to the bar using an injected JS finder (`__md2Find`/`__md2FindNext`) that wraps matches in `<mark>` and returns the localized match-status values the spec requires.
- [x] 4.4 Wire query changes and next/previous (and ⌘G / ⇧⌘G) to drive the web view search and update the status label; show "no results" when empty.

## 5. Lifecycle & polish

- [x] 5.1 Dismiss the preview find bar when `mode` or `documentIdentity` changes.
- [x] 5.2 Ensure preview find scrolling is not mis-captured as a mode-switch anchor (reuse existing scroll-suppression). (`window.__md2FindActive` gates `topAnchor` during match scrolling.)
- [x] 5.3 Build the app (`swift build`) — succeeds. Manual UI verification of the spec scenarios in both modes is pending a GUI run.
