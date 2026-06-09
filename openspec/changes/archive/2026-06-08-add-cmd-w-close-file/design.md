## Context

Markdown2 is a SwiftUI macOS app whose only declared `Scene` is `Settings { ... }`. Document windows are not driven by a `WindowGroup`; instead `MD2AppDelegate` creates plain `NSWindow` instances manually (`makeDocumentWindow`) and acts as their `NSWindowDelegate`. Because there is no `WindowGroup`, SwiftUI never contributes the standard File ▸ Close (⌘W) command, so ⌘W is unbound and there is no keyboard way to close the current file.

The unsaved-changes flow already exists and must be reused, not reinvented:
- `windowShouldClose(_:)` → `confirmDiscardOrSaveIfNeeded(for:)` runs when the window's close button is clicked.
- `applicationShouldTerminate(_:)` runs the same confirmation across every dirty window for ⌘Q.

Menu commands in this app are declared in `MD2App.swift` under `.commands { ... }` and act on `appDelegate.currentDocumentStore` (the store behind `NSApp.keyWindow`). Labels are localized through `settings.text(_:)` backed by the `L10nKey` enum in `AppSettings.swift`.

## Goals / Non-Goals

**Goals:**
- Bind ⌘W to close the frontmost document window.
- Reuse the existing Save / Cancel / Don't Save confirmation for dirty documents.
- Keep ⌘Q behavior byte-for-byte identical.
- Localize the new menu label (English + Simplified Chinese).

**Non-Goals:**
- No "Close All" / ⌥⌘W command.
- No change to native window tabbing behavior.
- No migration to a `WindowGroup`/`DocumentGroup` scene architecture.

## Decisions

### Route close through `NSWindow.performClose(_:)`

The Close command will call a new `MD2AppDelegate.closeCurrentDocument()` that resolves the target window (`NSApp.keyWindow`, falling back to the first managed window) and calls `performClose(nil)` on it.

`performClose` simulates clicking the close button: it sends `windowShouldClose(_:)` to the delegate and, if that returns `true`, proceeds to close and fire `windowWillClose`. This means the existing `confirmDiscardOrSaveIfNeeded` prompt and the `documentWindows` cleanup run automatically — no duplicated save/discard logic.

**Alternative considered:** Call `window.close()` directly. Rejected because `close()` bypasses `windowShouldClose`, skipping the unsaved-changes prompt and risking data loss — the opposite of the requirement.

**Alternative considered:** Add a SwiftUI `WindowGroup` so the standard Close command appears for free. Rejected as far too invasive; the app's entire window lifecycle is hand-managed in the delegate and would need rewriting.

### Place the command in the File menu near Save

Add the Close button in a `CommandGroup` so it lands in the File menu with `.keyboardShortcut("w")` (plain ⌘W). It targets the app delegate rather than `currentDocumentStore`, since closing is a window-level action.

### Localization

Add a `.close` case to `L10nKey` with `"Close"` (English) and `"关闭"` (Simplified Chinese), following the existing pattern.

## Risks / Trade-offs

- **Key window resolution differs from menu commands** → `closeCurrentDocument()` targets `NSApp.keyWindow`; if it is `nil` (no focused document window, e.g. only Settings open) the method no-ops safely instead of closing an arbitrary window.
- **⌘W could close the Settings window instead** → That is acceptable and matches standard macOS behavior; the close command only force-targets a document window when one is key, and the Settings scene already responds to ⌘W on its own.
- **Native tabs** → `performClose` closes a single tab/window, which is the expected per-file behavior; closing the last tab closes the window as usual.

## Migration Plan

Pure additive UI change. No data migration. Rollback is removing the Close button and the `.close` L10nKey.
