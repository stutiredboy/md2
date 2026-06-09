## 1. Settings model

- [x] 1.1 Add `newDocumentMode: EditorMode` to `AppSettings` with the `@Published`/`didSet` pattern, persisting to a new `Keys.newDocumentMode = "MD2.NewDocumentMode"`.
- [x] 1.2 Initialize `newDocumentMode` in `AppSettings.init` from defaults, falling back to `.write` when unset.
- [x] 1.3 Add `func presentationMode(isFileBacked: Bool) -> EditorMode` returning `defaultMode` when file-backed, else `newDocumentMode`.
- [x] 1.4 Add L10n keys for the two picker labels (e.g. `.fileOpenMode`, `.newDocumentMode`) with English + Simplified Chinese strings; keep/repurpose existing `.defaultOpenMode` as needed.

## 2. Mode selection wiring

- [x] 2.1 In `ContentView.init`, set `_mode` from `settings.presentationMode(isFileBacked: document.fileURL != nil)` instead of `settings.defaultMode`.
- [x] 2.2 In `ContentView.applyDefaultPresentation()`, set `mode` from `settings.presentationMode(isFileBacked: document.fileURL != nil)` instead of `settings.defaultMode`.

## 3. Settings UI

- [x] 3.1 In `SettingsView`, relabel the existing mode picker to the opened-file label.
- [x] 3.2 Add a second segmented Edit/Preview picker bound to `settings.newDocumentMode` with the new-document label.

## 4. Tests

- [x] 4.1 Add tests for `AppSettings.presentationMode(isFileBacked:)` covering file-backed → `defaultMode` and blank → `newDocumentMode` (use an isolated `UserDefaults`).
- [x] 4.2 Add a test asserting `newDocumentMode` defaults to `.write` when no preference is stored, and that `defaultMode` is unaffected.

## 5. Verification

- [x] 5.1 Run `swift build` and `swift test`; confirm all pass.
- [x] 5.2 Manually verify: direct launch / New opens in Edit; opening an existing file follows the opened-file setting; both settings persist across relaunch.
