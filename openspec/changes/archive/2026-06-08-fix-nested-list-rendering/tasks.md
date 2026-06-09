## 1. Capture indentation when parsing list items

- [x] 1.1 Add a leading-indentation measure to `parseListItem` in `Sources/MD2Core/MarkdownRenderer.swift`, counting leading spaces (tab = 4) before trimming, and surface it (e.g. an `indent`/`level` field on `ListItem` or a returned tuple)
- [x] 1.2 Compute nesting level from indentation using a step of 4 spaces / 1 tab == one level; level 0 for non-indented items

## 2. Build nested lists in listBlock

- [x] 2.1 Replace `listBlock`'s flat append loop with collection of the full run of consecutive list lines plus their levels, stopping at the first non-list line
- [x] 2.2 Implement a stack-based builder that opens a child `<ul>`/`<ol>` inside the previous `<li>` when level increases, and closes nested lists when level decreases, emitting `<li>text<ul>...</ul></li>`
- [x] 2.3 Set each (sub)list tag from its first item's kind (ul vs ol) so mixed ordered/unordered nesting works
- [x] 2.4 Apply the `task-list` class and disabled checkbox emission per (sub)list so nested task items keep their checkboxes

## 3. List vs. indented-code boundary

- [x] 3.1 Ensure 4-space/tab-indented list lines are consumed as nested list items within `listBlock` and are not intercepted as indented code
- [x] 3.2 Preserve indented-code rendering for indented lines that are not part of a surrounding list (e.g. standalone `    - x` after a paragraph/blank line)

## 4. Tests and verification

- [x] 4.1 Add nested-list tests in `Tests/MD2CoreTests/MarkdownRendererTests.swift` covering the 物料清单 example (one nested level), multi-level nesting, and dedent-closes-nested-list
- [x] 4.2 Add tests for nested task-list checkboxes and ordered-nested-under-unordered
- [x] 4.3 Add a regression test that a standalone indented `- item` outside any list still renders as indented code
- [x] 4.4 Run `swift test` and confirm all tests pass; spot-check the preview against the reference document
