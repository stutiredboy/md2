## Why

Pressing ⌘W does nothing in Markdown2, so there is no keyboard shortcut to quickly close the file the user is looking at. Because the app builds its document windows manually in `MD2AppDelegate` and exposes only a `Settings` scene (no `WindowGroup`), SwiftUI never installs the standard File ▸ Close command, leaving ⌘W unbound. Closing a file currently requires clicking the window's red traffic-light button.

## What Changes

- Add a **Close** menu command bound to ⌘W that closes the frontmost document window.
- Route the close through `NSWindow.performClose(_:)` so it triggers the existing `windowShouldClose(_:)` delegate path, reusing the current unsaved-changes prompt (Save / Cancel / Don't Save).
- Preserve ⌘Q behavior unchanged: quitting still walks every dirty window and prompts to save or discard via `applicationShouldTerminate`.
- Add a localized `.close` menu label (English + Simplified Chinese).

## Capabilities

### New Capabilities
- `document-window-close`: Closing the active document window from the keyboard (⌘W), including the unsaved-changes confirmation that protects against accidental data loss.

### Modified Capabilities
<!-- None: ⌘Q quit behavior is unchanged, and no existing spec covers window lifecycle. -->

## Impact

- `Sources/MD2App/MD2App.swift`: new `Close` command button with `.keyboardShortcut("w")`.
- `Sources/MD2App/MD2AppDelegate.swift`: a `closeCurrentDocument()` entry point that calls `performClose` on the key window (existing `windowShouldClose`/`confirmDiscardOrSaveIfNeeded` logic is reused, not duplicated).
- `Sources/MD2App/AppSettings.swift`: new `.close` `L10nKey` with English and `zhHans` strings.
- No change to `applicationShouldTerminate` (⌘Q) behavior.
