## Why

The single "Default Open Mode" setting governs the initial mode for *every* document — both brand-new/blank windows (launching the app directly) and opened existing files. A user who prefers to read existing files in Preview is forced to also land in Preview on a blank document, where the only sensible action is to start typing. New/blank documents should default to Edit, independently of how opened files are presented.

## What Changes

- Split the one mode preference into two independent settings:
  - **Mode when opening a file** — keeps the existing `MD2.DefaultMode` preference and its current behavior.
  - **Mode for new documents** — a new preference (default **Edit**) applied when the app opens a blank/untitled document (direct launch, `New`, or reopen with no windows).
- Centralize the choice in a single testable helper on `AppSettings` that resolves the presentation mode from whether the document is file-backed.
- Surface both settings as separate pickers in the Settings window, with localized labels (English + Simplified Chinese).
- Out of the box (no saved preference), new/blank documents open in Edit mode, satisfying the request without requiring any configuration.

## Capabilities

### New Capabilities
- `document-presentation-mode`: How the app selects a document's initial editor mode (Edit vs Preview) on launch/open, driven by separate preferences for new documents versus opened files.

### Modified Capabilities
<!-- None: no existing spec covers default-mode selection. -->

## Impact

- `Sources/MD2App/AppSettings.swift`: add `newDocumentMode` property + `MD2.NewDocumentMode` key, new L10n keys, and a `presentationMode(isFileBacked:)` helper.
- `Sources/MD2App/ContentView.swift`: use the helper in `init` and `applyDefaultPresentation()` instead of reading `defaultMode` directly.
- `Sources/MD2App/SettingsView.swift`: add the second picker and relabel the existing one.
- `Tests/MD2CoreTests/`: add coverage for `presentationMode(isFileBacked:)` and default values.
- User-facing: existing `MD2.DefaultMode` preference is preserved (now applies only to opened files); a new preference is introduced. No data migration required.
