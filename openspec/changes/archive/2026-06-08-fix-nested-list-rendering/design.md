## Context

`MarkdownRenderer.renderBody` walks lines and dispatches each to a block handler. Two handlers are relevant:

- `indentedCodeBlock` (checked first, around line 54) treats any line beginning with four spaces or a tab as indented code.
- `listBlock` (checked later, around line 112) consumes consecutive `parseListItem` lines into a single flat `<ul>`/`<ol>`.

`parseListItem` calls `trimmedMarkdownLine` (which trims all leading/trailing whitespace) before matching the bullet/number marker, so indentation is lost. As a result, `listBlock`'s loop appends every consecutive item — including indented ones — as flat siblings, producing one top-level list with no nesting.

A subtlety: because `listBlock` is entered at the first (non-indented) item, its inner loop reads the indented child lines directly via `parseListItem`, so they are *not* intercepted by `indentedCodeBlock`. The flattening therefore happens inside `listBlock`, and that is the primary thing to fix. The body-walk ordering only matters for the edge case where a list could begin or resume on an indented line.

## Goals / Non-Goals

**Goals:**
- Render nested lists driven by indentation depth (4 spaces or 1 tab == one level).
- Keep flat lists, ordered lists, task lists, and mixed ordered/unordered nesting working.
- Keep indented code blocks working when they are not part of a list.

**Non-Goals:**
- Full CommonMark list semantics (lazy continuation, loose vs. tight lists, paragraph/code children inside list items, blank-line grouping rules).
- Changing the inline rendering of item text.
- Configurable indentation width.

## Decisions

### Capture indentation in `parseListItem`
Change `parseListItem` to compute the item's leading-indentation width before trimming, and return it on `ListItem` (e.g. an `indent: Int` field, or a separate `(item, indent)` tuple). Indentation width is the count of leading spaces with a tab counting as 4. The nesting level is `indentWidth / 4` (integer division), which tolerates common 2- or 4-space styles by normalizing on a 4-space step; the implementation MAY instead derive levels from the relative ordering of observed indents to be robust to 2-space indentation. Decision: use a step of 4 spaces / 1 tab == one level, matching the failing example, and document it in the spec.

Alternative considered: keeping `parseListItem` whitespace-agnostic and measuring indent separately in `listBlock`. Rejected because `parseListItem` is the single place that already inspects the raw line, so threading indent through it keeps one source of truth.

### Build a nested tree in `listBlock`
Replace `listBlock`'s flat append loop with a stack-based builder:
1. Collect the run of consecutive list lines (with their indent levels), stopping at the first non-list line.
2. Walk the collected items maintaining a stack of open lists keyed by level. When an item's level is deeper than the current, open a child list nested inside the previous item's `<li>`. When shallower, close lists back to the matching level. The first item establishes level 0; the top list's tag (`ul`/`ol`) is set by the first item at each level.
3. Emit properly nested `<ul>`/`<ol>` with child lists rendered *inside* the parent `<li>` (before its closing tag), so output is `<li>text<ul>...</ul></li>`.

The existing `task-list` class and checkbox emission move into per-list emission so each (sub)list gets the class when any of its direct items is a task item.

Alternative considered: recursive descent (parse one level, recurse for deeper-indented runs). Equivalent in output; a stack is simpler to implement in one pass and easier to reason about for close-on-dedent.

### Body-walk ordering for indented list lines
To support the edge case where the renderer encounters an indented line that is a list item outside an already-open list, guard `indentedCodeBlock` so it does not claim a line that `parseListItem` would accept *when that line continues/relates to list context*. Minimal approach: since `listBlock` consumes its own indented children, the only needed guard is to ensure `listBlock` is given the chance to start. For the failing example this already works because the list starts at a non-indented line. Keep the change minimal: prefer `listBlock` over `indentedCodeBlock` only when the indented line is a list item AND the immediately preceding emitted block was a list (or the previous source line was a list item). Document the precise rule with the indented-code scenario in the spec.

## Risks / Trade-offs

- [Mixed 2-space vs 4-space indentation in real documents may not map cleanly to levels] → Normalize on a 4-space/tab step and document it; relative-indent inference is a possible later enhancement.
- [Over-eagerly preferring lists over indented code could break legitimate indented code that looks like a list (e.g. `    - dash in code`)] → Only prefer list parsing when adjacent to existing list context; standalone indented `- ...` after a blank line still renders as code.
- [Loose vs. tight list and multi-paragraph list items remain unsupported] → Explicitly a Non-Goal; behavior unchanged from today aside from nesting.

## Open Questions

- Should the indentation step be exactly 4 spaces, or should the renderer infer one level from the first observed indentation delta (to support 2-space styles)? Default chosen: 4 spaces / 1 tab; revisit if user documents use 2-space indentation.
