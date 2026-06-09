## Context

The editor (`MarkdownEditorView` + `MarkdownTextStyler`) is an `NSTextView` driven
by AppKit. Code-block lines are currently styled in
`MarkdownTextStyler.addCodeLineStyle` by adding two text attributes per line:

```swift
.font: monospaced 14
.backgroundColor: NSColor.textColor.withAlphaComponent(0.06)
```

The `.backgroundColor` text attribute is painted by the default
`NSLayoutManager` only behind each line fragment's **used rect** (the glyph
extent). The paragraph style sets `lineSpacing = 4` and `paragraphSpacing = 7`,
and each source line is its own paragraph. The default fill therefore skips:

1. the line/paragraph spacing between code lines → horizontal white "isolation
   bands" (Image #1),
2. the area to the right of short lines and most of an empty line → small white
   blocks, most noticeable right after switching from preview (Image #2).

This is an inherent limitation of `.backgroundColor`, not a bug in the styling
logic. The view already runs in TextKit 1 compatibility mode (it accesses
`textView.layoutManager` throughout), so a custom `NSLayoutManager` is viable.

## Goals / Non-Goals

**Goals:**
- Render each fenced code block as one continuous, full-width shaded panel.
- Cover empty/short lines and the inter-line spacing with shading.
- Keep inline-code backgrounds and find-highlight temporary backgrounds visible.
- Match the preview's code background tone and adapt to light/dark.

**Non-Goals:**
- No syntax highlighting in the editor (only block shading).
- No change to the preview renderer, document model, or file format.
- Rounded corners / horizontal insets are optional polish, not required.

## Decisions

### Decision 1: Draw code-block backgrounds in a custom NSLayoutManager

Subclass `NSLayoutManager` (e.g. `CodeBlockLayoutManager`) and override
`drawBackground(forGlyphRange:at:)`. For the glyph range being drawn, enumerate
line fragments via `enumerateLineFragments(forGlyphRange:)`. For each fragment
whose characters carry the code-block marker attribute, fill the **line fragment
rect** (which includes line and paragraph spacing) with the shading color,
overriding the width to the text container's width so short/empty lines and the
right margin are covered. Because line fragment rects tile the container with no
vertical gaps, consecutive filled fragments merge into one seamless panel.

- **Why over alternatives:**
  - *Override `fillBackgroundRectArray`*: only invoked for ranges that already
    carry `.backgroundColor`; it would still be driven by used rects and the
    per-paragraph segmentation — more fighting the framework than subclassing
    `drawBackground`.
  - *Draw in the NSTextView (`drawBackground(in:)`)*: requires re-deriving glyph
    geometry and coordinate conversions; the layout manager already has the
    fragment geometry.
  - *Keep `.backgroundColor` and only widen line fragments*: cannot remove the
    inter-line gap, which comes from spacing the attribute never fills.

### Decision 2: Mark code lines with a custom attribute, not `.backgroundColor`

In `MarkdownTextStyler.addCodeLineStyle`, replace the `.backgroundColor` attribute
with a custom marker key (e.g. `.markdownCodeBlock`). The layout manager reads
this marker to decide which fragments to fill. This avoids double-painting and
removes the per-line stripe behavior entirely.

### Decision 3: Draw the panel before calling super

Call the code-block fill first, then `super.drawBackground(...)`. Super paints
inline-code `.backgroundColor` and find/replace temporary background highlights,
so drawing them after the panel keeps them visible on top. (Find highlights use
`addTemporaryAttribute(.backgroundColor:)` in the coordinator and are unaffected
by the marker change.)

### Decision 4: Build the text stack manually with the custom layout manager

`NSTextView()` creates its own layout manager. To install the subclass, construct
the stack in `makeNSView`: `NSTextStorage` → `CodeBlockLayoutManager` →
`NSTextContainer` → `MarkdownSourceTextView(frame:textContainer:)`. Preserve the
current container/text-view configuration (inset, width tracking, resizing). This
also pins the view to TextKit 1, which the existing scroll/anchor code already
assumes.

### Decision 6: Keep inline styling out of code blocks (found during implementation)

The inline-code regex used `` `[^`]+` ``. Because `[^`]` matches newlines, a single
match ran from a fence's backtick across the whole block to the next fence's
backtick, painting an uneven `.backgroundColor` overlay over most of the panel
(and leaving the first two fence backticks un-overlaid as a lighter notch). Fixed
by (a) constraining the pattern to a single line (`` `[^`\n]+` ``) and (b) skipping
any inline match whose start carries the `.markdownCodeBlock` marker, so no inline
markdown is interpreted inside fenced code. This is required for the panel to read
as a uniform shade.

### Decision 5: Shading color

Use a tone matching the preview's `--code-bg` (`light-dark(#f6f8fa, #27272a)`).
Either keep the existing `NSColor.textColor.withAlphaComponent(0.06)` (already
appearance-adaptive and visually close) or map to the preview values via a
dynamic `NSColor`. Keep it appearance-aware either way.

## Risks / Trade-offs

- **TextKit 2 default drift** → Building the stack manually forces TextKit 1
  explicitly; behavior matches the current implicit TextKit 1 usage, so no
  regression in scroll/anchor/find code.
- **Performance of per-draw enumeration** → `drawBackground` only enumerates the
  fragments in the dirty glyph range, not the whole document; cost is bounded by
  what is on screen.
- **Coordinate/origin mistakes** → Fragment rects are container-relative; add the
  passed `origin` (and account for `textContainerInset`) before filling. Verify
  visually that the panel aligns with the code text.
- **Closing-fence trailing spacing** → The last code line carries `paragraphSpacing`;
  including it in the fill keeps the panel flush. Acceptable and matches a solid
  block; revisit only if a gap appears below the closing fence.

## Migration Plan

Pure in-app rendering change; no data migration. Rollback = revert the styler and
editor-view edits. Verify by opening a document with a multi-line code block
containing blank and short lines, and by toggling preview↔edit, in both light and
dark appearance.
