## Why

In edit mode, fenced code blocks are shaded by attaching a `.backgroundColor` text
attribute to each code line. That attribute only paints behind the glyphs' used
rect, so the editor's white background shows through the `lineSpacing` /
`paragraphSpacing` gaps between lines (white "isolation bands") and through empty
or short code lines (small white blocks, most visible right after switching from
preview to edit mode). The shading looks broken and makes multi-line code hard to
read.

## What Changes

- Introduce continuous, full-width shading for fenced code blocks in the editor so
  a block renders as one seamless panel instead of per-line stripes.
- Replace the per-line `.backgroundColor` attribute used for code lines with a
  custom marker attribute that a custom `NSLayoutManager` reads to fill each line
  fragment rect (which includes line/paragraph spacing) across the full container
  width.
- Keep inline-code shading and find-highlight temporary backgrounds rendering
  correctly on top of the new code-block panel.
- Use a shading color consistent with the existing preview code background.

## Capabilities

### New Capabilities
- `editor-code-block-styling`: How fenced code blocks are visually shaded in the
  source editor (edit mode), including continuous full-width background, empty/short
  line coverage, and interaction with inline code and find highlights.

### Modified Capabilities
<!-- None: no existing spec covers editor source styling. -->

## Impact

- `Sources/MD2App/MarkdownTextStyler.swift`: mark code lines with a custom attribute
  instead of `.backgroundColor`.
- `Sources/MD2App/MarkdownEditorView.swift`: build the text stack with a custom
  `NSLayoutManager` (TextKit 1) that draws code-block backgrounds.
- New layout manager type (e.g. `CodeBlockLayoutManager`).
- No change to document content, file format, or the preview renderer.
