## Why

Multi-line blockquotes (and multi-line paragraphs in general) collapse onto a
single rendered line because soft line breaks are joined with a space, matching
strict CommonMark. Users author content line-by-line and expect each line to be
preserved visually, so this reads as a bug — most editor-oriented Markdown tools
(Typora, GitHub comments, DingTalk) render soft breaks as visible line breaks.

## What Changes

- Render soft line breaks as `<br>` everywhere a paragraph is produced, so each
  authored line stays on its own line in both regular paragraphs and blockquotes.
- The fix is applied at the shared paragraph renderer, so blockquotes inherit the
  behavior automatically (no blockquote-specific branch).
- Existing hard breaks (trailing two spaces or `\`) continue to produce `<br>`
  unchanged; the change only affects what previously became a joining space.
- **BREAKING** (rendering behavior): output for any document with multi-line
  paragraphs changes — adjacent lines now emit `<br>` instead of a single space.
- Update `Docs/MarkdownSupport.md` to describe the line-break behavior.

## Capabilities

### New Capabilities
- `line-break-rendering`: How the renderer turns authored line breaks into HTML —
  soft breaks become `<br>`, hard breaks remain `<br>`, blank lines still separate
  blocks, and the rule applies uniformly inside paragraphs and blockquotes.

### Modified Capabilities
<!-- No existing spec covers paragraph/line-break rendering; nothing to modify. -->

## Impact

- `Sources/MD2Core/MarkdownRenderer.swift` — `paragraphHTML` (the soft-break join);
  blockquotes inherit the change via `blockquoteBlock` → `renderBody`.
- Tests: `Tests/MD2CoreTests/MarkdownRendererTests.swift`,
  `Tests/MD2CoreTests/MarkdownSyntaxCoverageTests.swift` (existing `<br>`
  expectations must still hold; add soft-break-as-`<br>` coverage).
- Docs: `Docs/MarkdownSupport.md`.
- No API, dependency, or data-format changes; HTML output only.
