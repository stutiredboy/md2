## Context

`MarkdownRenderer` is a single-file, regex-based renderer. `render(_:)` builds an outline, then `renderBody` walks normalized lines block-by-block, and each block's text is passed through `inlineHTML(_:)` for inline formatting. `inlineHTML` is **stateless and per-fragment**: it protects code/math/HTML with private-use-area placeholder tokens, escapes HTML, applies emphasis/link/image regexes, then restores placeholders.

Footnotes are different from every existing construct because they require **document-wide shared state**:
- A reference `[^id]` must be numbered by first-reference order across the whole document.
- A definition `[^id]: …` may appear far from its reference and must be lifted out of body flow.
- The footnotes section is emitted once, after all blocks, only for definitions that were referenced.
- Back-reference links require knowing every location an id was referenced.

This is the first construct that cannot be handled purely inside the stateless per-block `inlineHTML`.

## Goals / Non-Goals

**Goals:**
- Render `[^id]` references as numbered superscript links and emit a footnotes section with back-references, matching Typora's behavior and output shape closely enough for typical documents.
- Keep code/math protection precedence intact: footnote syntax inside code never becomes a footnote.
- Preserve offline rendering and light/dark legibility, consistent with math/diagram specs.
- Handle missing definitions, unreferenced definitions, and duplicate references without breaking the rest of the document.

**Non-Goals:**
- Full CommonMark/GFM footnote edge-case parity (e.g. complex nested block content inside a definition beyond simple multi-line continuation).
- Footnote support in the editor/source view (this is a Read-mode preview feature only).
- Reordering or de-duplicating footnote display numbers to match label text — numbering is purely first-reference order.

## Decisions

### Decision 1: Three-phase processing with a shared footnote context

Introduce a per-`render` mutable `FootnoteContext` (a reference type / `class`, or an `inout` struct threaded through the body walk) that holds:
- `definitions: [String: [String]]` — label → raw content lines, populated by the definition pass.
- `order: [String]` — labels in first-reference order, assigning display numbers.
- `referenceCounts: [String: Int]` — to generate unique back-reference anchor ids for duplicate references.

Phases:
1. **Definition collection (pre-pass over blocks):** While walking lines in `renderBody`, detect `^\[\^(id)\]:` at a line start (outside code/math/fenced blocks, which are already consumed first by their own block detectors) and absorb the definition plus indented continuation lines into `definitions`. These lines produce no body output.
2. **Inline reference substitution:** When `inlineHTML` runs for each block, footnote references `[^id]` are replaced — but only for ids that have a definition. Numbering/anchor bookkeeping mutates the shared context. Because `inlineHTML` is currently stateless, the context is passed in (new overload `inlineHTML(_:context:)`, with the existing signature delegating with a no-op context for call sites that don't need footnotes, e.g. headings).
3. **Footnotes-section emission (post-pass):** After all blocks, if `order` is non-empty, append a footnotes section (an `<ol>` / `<section class="footnotes">`) rendering each referenced definition's content via `inlineHTML`, with back-reference links.

*Alternative considered:* a regex-only single pass like other constructs. Rejected — numbering, cross-block references, and back-references are inherently stateful and order-dependent; a stateless per-block regex cannot assign global numbers or collect a trailing section.

### Decision 2: Protect references before HTML-escape, like code/math

Footnote reference substitution must run **inside** `inlineHTML`'s protected region, after code/math/autolink/HTML protection but the produced `<sup><a>…</a></sup>` must survive HTML-escaping. Follow the established pattern: match `\[\^([^\]\s]+)\]`, and emit the anchor via the existing `protect(...)` placeholder mechanism so it is restored verbatim after escaping. This guarantees footnote syntax inside `` `code` `` (already protected earlier) is never matched.

### Decision 3: Definition detection lives in the block walk, not inline

Definitions are block-level. Detect them in `renderBody` *before* the paragraph fallback, mirroring how `fencedCodeBlock`, `mathBlock`, etc. are tried in order. A new `footnoteDefinitionBlock(from:startIndex:)` consumes the `[^id]:` line and any indented continuation lines, stores content in the context, and returns the next index with **no emitted HTML**. Fenced/indented code and math blocks are matched earlier in the loop, so `[^id]:` inside them is never seen here.

### Decision 4: Anchor id scheme

- Definition anchor: `id="fn-<label>"`.
- Reference anchor (for back-links): `id="fnref-<label>"`, or `id="fnref-<label>-<n>"` for the n-th duplicate reference (n ≥ 2), so each back-reference link `href="#fnref-<label>[-n]"` targets a distinct location.
- Labels are sanitized for use in ids/attributes via the existing `escapeAttribute`/slug helpers to avoid breaking HTML when labels contain unusual characters.

### Decision 5: Styling

Add CSS in `htmlDocument` for `sup.footnote-ref a`, `section.footnotes` (top border / smaller font), and `.footnote-backref`, using `currentColor`/existing link variables so light and dark modes inherit correctly. No new bundled assets are required; footnotes are pure HTML+CSS, preserving offline rendering.

## Risks / Trade-offs

- **[Stateful inlineHTML breaks assumptions]** → Keep the original stateless `inlineHTML(_:)` signature working by delegating to the context-aware overload with a context that has no definitions, so reference substitution is a no-op there; only the body walk passes the real context.
- **[Definition vs. ordered-list / link-reference ambiguity]** → The `[^id]:` prefix (caret immediately after `[`) is distinct from link reference definitions `[id]:` and list markers, so detection is unambiguous with a `\[\^` anchor.
- **[Reference appears before its definition]** → The definition collection pre-pass must complete (or definitions must be gathered) before reference substitution decides whether an id is "known". Simplest: run a quick whole-document scan for `[^id]:` definition lines (respecting code fences) to build `definitions` before rendering blocks, then do numbering during block rendering. This avoids forward-reference ordering problems.
- **[Labels with HTML-unsafe characters]** → Sanitize before placing in `id`/`href`; if sanitization collisions occur, fall back to first-reference index to keep anchors unique.
- **[Multi-line definition indentation rules]** → Adopt a simple rule (continuation lines are indented by ≥2 spaces or a tab); document it and cover with a test. Full lazy-continuation parity is a non-goal.

## Migration Plan

Additive feature; no data migration. Rollback is removing the footnote passes and CSS. Existing documents without footnote syntax render byte-identically because no `[^…]` patterns match.

## Open Questions

- Exact superscript label display: numeric `1` (chosen) vs. echoing the literal label. Decision: numeric, matching Typora's rendered output.
- Whether to render a visible heading/separator above the footnotes section. Decision: a top border rule only (no text heading), to stay visually quiet per the app's design ethos; revisit if users expect a "Footnotes" heading.
