## Context

`AppSettings.defaultMode` (UserDefaults key `MD2.DefaultMode`, default `.write`) is read by `ContentView` in two places:

- `init` — `_mode = State(initialValue: settings.defaultMode)` (`ContentView.swift:42`).
- `applyDefaultPresentation()` — `mode = settings.defaultMode` (`ContentView.swift:126`), invoked on `document.documentIdentity` change.

A document is created blank (`DocumentStore()` → `fileURL == nil`, starter text) and only later becomes file-backed when `open(_:)` loads a URL, which bumps `documentIdentity`. So for opened files the flow is: window built blank → `init` runs (no URL yet) → `open()` fires → `documentIdentity` changes → `applyDefaultPresentation()` re-applies. Blank/new documents only ever go through `init` (no `documentIdentity` change).

This means the file-backed vs. blank distinction is observable at both call sites via `document.fileURL`.

## Goals / Non-Goals

**Goals:**
- New/blank documents (direct launch, `New`, reopen-with-no-windows) default to Edit mode, independently of the opened-file preference.
- The opened-file mode remains user-configurable and preserves any preference already saved under `MD2.DefaultMode`.
- The selection rule lives in one testable place rather than being duplicated in the view.

**Non-Goals:**
- No per-document persistence of the last-used mode.
- No third "follow the file default" linkage between the two settings — two independent pickers are enough.
- No change to the mode-switching/anchoring behavior once a document is open.

## Decisions

### Decision 1: Two independent settings, not a hard-coded rule
Add `newDocumentMode: EditorMode` (key `MD2.NewDocumentMode`, default `.write`) alongside the existing `defaultMode`, whose meaning narrows to "mode when opening a file."

- **Why:** Keeps the requested default (new docs → Edit) while remaining configurable. Reuses the existing `EditorMode` enum and the established `@Published`/`didSet`/UserDefaults pattern in `AppSettings`.
- **Alternative — hard-code blank → Edit:** simplest, but removes user choice and bakes policy into the view. Rejected.
- **Alternative — three-way enum (`follow` / `edit` / `preview`):** more expressive but adds a new type and UI complexity; two pickers set to the same value already cover "treat them the same." Rejected for simplicity.

### Decision 2: Centralize the choice in `AppSettings.presentationMode(isFileBacked:)`
```swift
func presentationMode(isFileBacked: Bool) -> EditorMode {
    isFileBacked ? defaultMode : newDocumentMode
}
```
`ContentView` calls it in both `init` (`isFileBacked: document.fileURL != nil`) and `applyDefaultPresentation()` (same expression).

- **Why:** A pure function over the two stored values is unit-testable without SwiftUI/AppKit, and removes the duplicated `settings.defaultMode` reads from the view. The existing `applyDefaultPresentation()` re-run on `documentIdentity` change naturally corrects the mode once a file URL is present, so opened-in-a-fresh-window files resolve to the opened-file mode even though `init` ran before the URL was set.

### Decision 3: Settings UI — two labeled pickers
Relabel the current picker to "Default mode when opening a file" and add "Default mode for new documents" below it, both segmented Edit/Preview. Add L10n keys for both labels in English and Simplified Chinese; the new-document key defaults to Edit.

## Risks / Trade-offs

- [Brief transient mode on open-in-new-window] When `newDocumentMode` is Edit and the opened-file mode is Preview, a freshly created window evaluates Edit in `init` before `open()` triggers `applyDefaultPresentation()` to switch to Preview. → The heavy preview surface is only built on demand and the window is still being composed, so the transient is not user-visible; this mirrors the existing double-apply (`init` then `applyDefaultPresentation`).
- [Setting label confusion] Two similar mode pickers could be mistaken for one another. → Distinct, explicit labels ("opening a file" vs "new documents") in both languages.

## Migration Plan

No data migration. The existing `MD2.DefaultMode` value is read unchanged and now applies to opened files. `MD2.NewDocumentMode` is absent for existing users, so it resolves to its default (`.write`/Edit) — exactly the requested behavior — until they change it. Rollback is removing the new key/property; `defaultMode` reverts to governing both cases.
