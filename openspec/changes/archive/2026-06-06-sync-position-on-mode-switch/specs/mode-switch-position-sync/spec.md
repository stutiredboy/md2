## ADDED Requirements

### Requirement: Preserve position when switching Write to Read
When the user switches from Write (editor) mode to Read (preview) mode, the system SHALL scroll the preview so the content the user was at in the editor remains in view, rather than resetting to the top of the document. The system SHALL anchor on the section heading at or above the editor's current position, using the document outline's source-line-to-element-id mapping.

#### Scenario: Editor viewport under a heading carries into the preview
- **WHEN** the editor is scrolled so the top visible line falls within a section whose heading is `## Installation`
- **AND** the user switches to Read mode
- **THEN** the preview scrolls so the `Installation` heading (and its content) is in view near the top of the viewport
- **AND** the preview does NOT reset to the top of the document

#### Scenario: Switching at the top of the document stays at the top
- **WHEN** the editor is scrolled to the very top
- **AND** the user switches to Read mode
- **THEN** the preview shows the top of the document

### Requirement: Preserve position when switching Read to Write
When the user switches from Read (preview) mode to Write (editor) mode, the system SHALL scroll the editor so the source for the content the user was reading remains in view, rather than resetting to the top. The system SHALL anchor on the heading currently at the top of the preview viewport and scroll the editor to that heading's source line.

#### Scenario: Preview viewport at a heading carries into the editor
- **WHEN** the preview is scrolled so the `## Usage` section heading is at the top of the viewport
- **AND** the user switches to Write mode
- **THEN** the editor scrolls so the source line of the `## Usage` heading is in view
- **AND** the editor does NOT reset to the first line

#### Scenario: Round trip returns to roughly the same section
- **WHEN** the user is editing within a section partway down the document
- **AND** the user switches to Read mode and then back to Write mode without scrolling
- **THEN** the editor is positioned within the same section it started from

### Requirement: Heading-granularity anchoring
The system SHALL preserve position at section/heading granularity. It is NOT required to align the cursor or scroll offset exactly; landing within the same section as the source mode satisfies the requirement.

#### Scenario: Position lands in the same section, not necessarily the same line
- **WHEN** the user switches modes while positioned several paragraphs below a heading
- **THEN** the destination viewport shows that heading's section
- **AND** an offset of a few lines or paragraphs from the exact original position is acceptable

### Requirement: Fallback for content without an anchoring heading
When there is no section heading at or above the user's current position (for example, content before the first heading, or a document with no headings at all), the system SHALL apply a best-effort proportional position based on the relative scroll fraction so the destination viewport still tracks the source position approximately, and SHALL NOT silently jump to the top of the document.

#### Scenario: Document with no headings tracks proportionally
- **WHEN** a document contains no headings
- **AND** the user is scrolled to roughly the middle of the editor
- **AND** the user switches to Read mode
- **THEN** the preview is scrolled to roughly the middle of the document

#### Scenario: Content above the first heading
- **WHEN** the user is positioned in introductory text that appears before the document's first heading
- **AND** the user switches modes
- **THEN** the destination viewport shows the beginning region of the document rather than skipping to the first heading's section
