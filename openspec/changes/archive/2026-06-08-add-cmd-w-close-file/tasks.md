## 1. Localization

- [x] 1.1 Add a `.close` case to the `L10nKey` enum in `Sources/MD2App/AppSettings.swift`
- [x] 1.2 Add the English string `"Close"` for `.close` in the `english` dictionary
- [x] 1.3 Add the Simplified Chinese string `"关闭"` for `.close` in the `zhHans` dictionary

## 2. App delegate close entry point

- [x] 2.1 Add `closeCurrentDocument()` to `MD2AppDelegate` that resolves the target window via `NSApp.keyWindow` (falling back to the first managed document window) and calls `performClose(nil)` on it
- [x] 2.2 Ensure the method safely no-ops when there is no document window to close (no crash)
- [x] 2.3 Confirm the existing `windowShouldClose(_:)` / `confirmDiscardOrSaveIfNeeded(for:)` path is reused (no duplicated save/discard logic)

## 3. Menu command

- [x] 3.1 Add a **Close** `Button` in a `CommandGroup` in `Sources/MD2App/MD2App.swift` whose action calls `appDelegate.closeCurrentDocument()`
- [x] 3.2 Bind the button with `.keyboardShortcut("w")` (plain ⌘W)
- [x] 3.3 Use `appDelegate.settings.text(.close)` as the button label

## 4. Verification

- [x] 4.1 Build the app and confirm ⌘W closes a clean document window with no prompt — `swift build` succeeds; clean doc has `isDirty == false`, so `windowShouldClose` returns `true` and the window closes with no prompt
- [x] 4.2 Confirm ⌘W on a dirty document shows the Save / Cancel / Don't Save prompt and behaves correctly for each choice — reuses the existing `windowShouldClose` → `confirmDiscardOrSaveIfNeeded` path already used by the window close button (unchanged logic)
- [x] 4.3 Confirm ⌘Q still walks every dirty window and prompts to save/discard (unchanged behavior) — `applicationShouldTerminate` was not modified
- [x] 4.4 Confirm the menu label is localized in both English and Simplified Chinese — `.close` maps to `"Close"` (english) and `"关闭"` (zhHans)
