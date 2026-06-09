## 1. Marker attribute

- [x] 1.1 Define a custom code-block marker attribute key (e.g. `NSAttributedString.Key.markdownCodeBlock`)
- [x] 1.2 In `MarkdownTextStyler.addCodeLineStyle`, replace `.backgroundColor` with the marker attribute (keep the monospaced font)

## 2. Custom layout manager

- [x] 2.1 Add `CodeBlockLayoutManager: NSLayoutManager` in `Sources/MD2App`
- [x] 2.2 Override `drawBackground(forGlyphRange:at:)`: enumerate line fragments, fill the full-width line-fragment rect for fragments whose characters carry the marker, then call `super`
- [x] 2.3 Use an appearance-adaptive shading color matching the preview `--code-bg`

## 3. Wire the layout manager into the editor

- [x] 3.1 In `MarkdownEditorView.makeNSView`, build the stack manually: `NSTextStorage` → `CodeBlockLayoutManager` → `NSTextContainer` → `MarkdownSourceTextView(frame:textContainer:)`
- [x] 3.2 Preserve existing text-view config (inset, width tracking, resizing, background) on the manually built view

## 4. Verify

- [x] 4.1 Build the app and open a document with a multi-line code block containing blank and short lines; confirm continuous full-width shading with no white bands or blocks
- [x] 4.2 Toggle preview↔edit and confirm no small white blocks appear
- [x] 4.3 Confirm inline code shading and find-match highlights render on top of the panel
- [x] 4.4 Confirm correct appearance in both light and dark mode
