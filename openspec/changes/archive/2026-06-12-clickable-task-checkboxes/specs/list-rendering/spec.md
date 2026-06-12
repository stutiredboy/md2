## MODIFIED Requirements

### Requirement: Task list and mixed-kind nesting preservation
The system SHALL preserve task-list rendering and mixed ordered/unordered nesting. A list item written as `- [ ]` or `- [x]` SHALL render with an enabled (clickable) checkbox reflecting the checked state, including when nested. Each task checkbox SHALL carry a `data-md2-task-line` attribute holding the 1-based source line of its list item, absolute with respect to the whole document (including items rendered inside blockquotes). A nested child list MAY be of a different kind (ordered vs. unordered) than its parent.

#### Scenario: Nested task list items keep checkboxes
- **WHEN** a parent item has a nested child item written as `    - [x] done`
- **THEN** the nested child renders inside a child list with a checked, enabled checkbox

#### Scenario: Checkbox carries its source line
- **WHEN** the third line of the document is `- [ ] Ship`
- **THEN** its rendered checkbox input carries `data-md2-task-line="3"`

#### Scenario: Task item inside a blockquote carries an absolute line
- **WHEN** a `> - [ ] quoted` task line is the fifth line of the document
- **THEN** its rendered checkbox input carries `data-md2-task-line="5"`

#### Scenario: Ordered list nested under unordered item
- **WHEN** a `- parent` item is followed by `    1. step one` and `    2. step two`
- **THEN** the `parent` item contains a nested `<ol>` with two items
