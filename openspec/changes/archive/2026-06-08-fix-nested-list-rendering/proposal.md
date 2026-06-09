## Why

Nested (indented) unordered and ordered lists do not render as nested in the Read-mode preview. The renderer strips all leading whitespace from each list item before parsing, so indentation is discarded and every item collapses into a single flat top-level list. Source such as:

```
- 空调
    - 内外机
    - 安装（铜、电缆）
    - 人工
- 电缆
- 配电箱
```

renders as one flat `<ul>` instead of a parent list with a nested child list under `空调`.

## What Changes

- Track each list item's leading-indentation width when parsing list lines, instead of trimming it away.
- Build a nested `<ul>`/`<ol>` tree from indentation depth, so deeper-indented items become child lists of the preceding shallower item.
- Ensure 4-space-indented list lines are recognized as nested list items rather than being intercepted as indented code blocks while a list is being consumed.
- Preserve existing behavior for flat lists, task lists (checkboxes), ordered lists, and mixed ordered/unordered nesting.

## Capabilities

### New Capabilities
- `list-rendering`: Markdown rendering of ordered and unordered lists, including nested lists driven by indentation depth, task-list checkboxes, and the boundary between list items and indented code.

### Modified Capabilities
<!-- None: list rendering has no existing spec; introduced as a new capability. -->

## Impact

- `Sources/MD2Core/MarkdownRenderer.swift`: `listBlock`, `parseListItem`, and the body-walk ordering between `indentedCodeBlock` and `listBlock`.
- Possibly `Sources/MD2Core/MarkdownLine.swift` for indentation helpers.
- Tests under `Tests/` covering nested list rendering.
- No changes to public APIs or dependencies.
