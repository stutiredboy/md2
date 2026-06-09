## Why

Markdown2 renders most of Typora's Markdown surface, but footnotes are missing. Footnotes are a common need in academic, technical, and long-form writing for adding citations and asides without cluttering the main text. Without them, documents authored in Typora that use footnotes render their raw `[^id]` and `[^id]: ...` syntax as literal text in the Read-mode preview.

## What Changes

- Detect inline footnote references (`[^id]`) in paragraph and other inline text and render each as a small superscript link that points to the matching footnote definition.
- Detect footnote definitions (`[^id]: text`) as block-level constructs, remove them from the document body, and collect their content.
- Render a footnotes section at the bottom of the document containing the collected definitions in order of first reference, each with a back-reference link returning to the referencing location.
- Support multi-line / continuation footnote definitions (indented continuation lines belong to the preceding definition).
- Handle edge cases gracefully: references with no definition, definitions never referenced, duplicate references to the same definition, and footnote-like syntax inside code (which must stay literal).
- Update `Examples/Sample.md` with a footnotes section demonstrating the syntax.

## Capabilities

### New Capabilities
- `footnote-rendering`: Detecting Markdown footnote references and definitions, rendering references as superscript anchor links, and emitting a collected footnotes section with bidirectional navigation links, fully offline in the Read-mode preview.

### Modified Capabilities
<!-- None: footnotes are a self-contained new capability; existing math/diagram specs are unaffected. -->

## Impact

- `Sources/MD2Core/MarkdownRenderer.swift`: new block-level definition collection pass, inline reference substitution, and footnotes-section emission; ordering of inline passes so code is protected before footnote references are matched.
- `Sources/MD2Core/Resources` / preview CSS in `MarkdownRenderer.htmlDocument`: styling for superscript references, the footnotes section, and back-reference links in light and dark mode.
- `Examples/Sample.md`: new demonstration content.
- `Tests/MD2CoreTests`: new rendering tests for references, definitions, ordering, and edge cases.
