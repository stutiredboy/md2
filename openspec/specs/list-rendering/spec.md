## ADDED Requirements

### Requirement: Flat list rendering
The system SHALL render a run of consecutive list lines of a single kind as one HTML list: lines beginning with `-`, `*`, or `+` (followed by a space) as an unordered list (`<ul>`), and lines beginning with a number followed by `.` or `)` and a space as an ordered list (`<ol>`). Each list line SHALL become one `<li>` whose content is the item text rendered with inline Markdown formatting.

#### Scenario: Unordered list renders as ul
- **WHEN** the source contains the lines `- 电缆` and `- 配电箱`
- **THEN** the preview renders a single `<ul>` containing two `<li>` items with text `电缆` and `配电箱`

#### Scenario: Ordered list renders as ol
- **WHEN** the source contains the lines `1. first` and `2. second`
- **THEN** the preview renders a single `<ol>` containing two `<li>` items

### Requirement: Nested list rendering by indentation
The system SHALL determine each list item's nesting level from its leading-whitespace indentation, and SHALL render items indented more deeply than the preceding item as a child list nested inside that preceding item's `<li>`. Returning to a shallower indentation SHALL close the deeper child list(s) and continue the appropriate ancestor list. Indentation SHALL be measured so that a tab or four spaces represents one additional nesting level.

#### Scenario: Single level of nesting
- **WHEN** the source contains:
  ```
  - 空调
      - 内外机
      - 安装（铜、电缆）
      - 人工
  - 电缆
  - 配电箱
  ```
- **THEN** the preview renders a top-level `<ul>` with three items `空调`, `电缆`, `配电箱`
- **AND** the `空调` item contains a nested `<ul>` with three items `内外机`, `安装（铜、电缆）`, `人工`
- **AND** `电缆` and `配电箱` are siblings of `空调`, not children of it

#### Scenario: Returning to a shallower level closes nested lists
- **WHEN** a child item is followed by an item at the parent's indentation level
- **THEN** the nested child list is closed
- **AND** the following item is rendered as a sibling of the parent item

#### Scenario: Multiple nesting levels
- **WHEN** the source contains an item, a child indented one level, and a grandchild indented two levels
- **THEN** the grandchild renders inside a list nested within the child's `<li>`, which is itself nested within the top-level item's `<li>`

### Requirement: Nested list lines are not treated as indented code
The system SHALL recognize a four-space- or tab-indented line that is itself a list item as a nested list item while a list is being parsed, rather than treating it as an indented code block. Indented code handling SHALL continue to apply to indented lines that are not part of a surrounding list.

#### Scenario: Four-space indented list item nests instead of becoming code
- **WHEN** a `- parent` line is immediately followed by a `    - child` line indented with four spaces
- **THEN** the `child` line renders as a nested list item under `parent`
- **AND** the literal text `- child` does not appear inside a `<pre>`/`<code>` code block

#### Scenario: Indented code outside a list is unaffected
- **WHEN** a four-space-indented line that is not a list item appears outside any list (for example after a blank line following a paragraph)
- **THEN** it is still rendered as an indented code block

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
