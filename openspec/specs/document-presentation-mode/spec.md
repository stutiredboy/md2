## ADDED Requirements

### Requirement: Separate default mode for new documents and opened files
The app SHALL maintain two independent preferences for a document's initial editor mode: one for new/blank documents and one for documents opened from a file. New/blank documents SHALL use the new-document preference; documents opened from a file SHALL use the opened-file preference. The selection SHALL be resolved from whether the document is backed by a file.

#### Scenario: Direct launch opens a blank document in the new-document mode
- **WHEN** the app launches with no file argument and presents a new blank document
- **THEN** the document is shown in the configured new-document mode

#### Scenario: Opening a file uses the opened-file mode
- **WHEN** a Markdown file is opened (via file argument, the Open panel, or Finder)
- **THEN** the document is shown in the configured opened-file mode regardless of the new-document mode

#### Scenario: New command uses the new-document mode
- **WHEN** the user creates a document with the New command
- **THEN** the document is shown in the configured new-document mode

#### Scenario: Reusable blank window adopts the opened-file mode when a file loads into it
- **WHEN** an untouched blank window is reused to load an opened file
- **THEN** the document switches to the configured opened-file mode

### Requirement: New documents default to Edit mode
When no new-document mode preference has been saved, the app SHALL default new/blank documents to Edit mode.

#### Scenario: First run, no saved preference
- **WHEN** the app opens a new/blank document and no new-document mode preference exists
- **THEN** the document is shown in Edit mode

#### Scenario: Existing opened-file preference is preserved
- **WHEN** a user already has a saved default-mode preference from before this change
- **THEN** that preference continues to apply to documents opened from a file
- **AND** new/blank documents default to Edit mode

### Requirement: Both modes are configurable in Settings
The Settings window SHALL expose both the new-document mode and the opened-file
mode as separate, clearly labeled controls offering Edit, Side by Side, and
Preview, with labels localized in English and Simplified Chinese. Changes SHALL
persist across launches.

#### Scenario: User changes the new-document mode
- **WHEN** the user sets the new-document mode to Preview in Settings
- **THEN** subsequently created new/blank documents are shown in Preview mode
- **AND** the choice persists after relaunching the app

#### Scenario: Opened-file mode is independent
- **WHEN** the user sets the opened-file mode to Preview and leaves the new-document mode at Edit
- **THEN** opened files are shown in Preview while new/blank documents remain in Edit

#### Scenario: User selects Side by Side as a default mode
- **WHEN** the user sets the new-document mode (or the opened-file mode) to
  Side by Side in Settings
- **THEN** subsequently created new/blank documents (or opened files) are shown
  in Side by Side mode
- **AND** the choice persists after relaunching the app

### Requirement: Side by Side is an available presentation mode
The app SHALL support Side by Side as a third presentation mode value that both
the new-document mode preference and the opened-file mode preference can hold.
When either preference is set to Side by Side, the document SHALL be resolved to
Side by Side mode on open using the same file-backed vs. new-document resolution
as the other modes. A previously saved Edit or Preview preference SHALL continue
to resolve unchanged.

#### Scenario: Opened-file preference set to Side by Side
- **WHEN** the opened-file mode preference is Side by Side and a Markdown file is
  opened
- **THEN** the document is shown in Side by Side mode

#### Scenario: Existing Edit/Preview preferences are unaffected
- **WHEN** a user already has a saved Edit or Preview mode preference from before
  this change
- **THEN** that preference continues to resolve to the same mode
