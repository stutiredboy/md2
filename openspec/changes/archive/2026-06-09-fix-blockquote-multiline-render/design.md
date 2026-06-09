## Context

`MarkdownRenderer` (in `Sources/MD2Core/MarkdownRenderer.swift`) is a hand-rolled,
mostly CommonMark-aligned renderer. `paragraphHTML(_:footnotes:)` is the single
place where the lines of a paragraph are turned into inline HTML. Today it joins
adjacent non-hard-break lines with a space:

```swift
if index < lines.count - 1 {
    return "\(inlineHTML(content, footnotes: footnotes)) "   // soft break → space
}
```

Blockquotes do not have their own paragraph logic: `blockquoteBlock` strips the
`>` markers, joins the inner lines with `\n`, and re-enters `renderBody`, which
ultimately calls `paragraphHTML`. So fixing the soft-break behavior in one place
fixes both paragraphs and blockquotes.

The bug report is about blockquotes, but the user confirmed the desired scope is
**global**: soft breaks should render as `<br>` everywhere (Typora / GitHub-comment
style), not only inside blockquotes.

## Goals / Non-Goals

**Goals:**
- A soft line break inside any paragraph renders as `<br>`.
- Blockquotes inherit the behavior with no blockquote-specific code.
- Hard breaks (trailing `  ` or `\`) keep working exactly as before.
- Blank lines still separate blocks; no change to block detection.

**Non-Goals:**
- No change to list-item, table, code-block, or heading line handling.
- Not adding a toggle/setting to switch between CommonMark and break-preserving
  modes — a single global behavior is chosen.
- No change to inline parsing (`inlineHTML`).

## Decisions

**Decision: Replace the soft-break space with `<br>` in `paragraphHTML`.**
The only change is the non-last-line branch: instead of appending a trailing
space, emit a `<br>`. The existing hard-break branch already emits `<br>`, so the
two branches converge — every non-final line of a paragraph ends with `<br>`,
whether the break was soft or hard. The final line emits no trailing break.

Rationale: minimal, localized, single-responsibility edit at the exact seam where
soft breaks were being collapsed. Blockquotes need no edit because they funnel
through this function.

*Alternative considered — blockquote-only fix:* add special handling in
`blockquoteBlock` to insert `<br>`. Rejected: duplicates paragraph logic, leaves
paragraphs inconsistent with blockquotes, and contradicts the confirmed global
scope.

*Alternative considered — make it configurable:* add an `AppSettings` flag.
Rejected as over-engineering for a behavior the user wants on unconditionally;
can be revisited if a CommonMark-strict mode is ever requested.

**Decision: Keep hard-break detection unchanged.**
The trailing-`\` content trimming and the `  `/`\` suffix check stay as-is; only
the soft-break fall-through changes. This keeps hard breaks distinguishable in
source even though both now yield `<br>`.

## Risks / Trade-offs

- **[Output divergence from CommonMark]** → Documented in `Docs/MarkdownSupport.md`
  as intended editor behavior; matches user expectation and common editors.
- **[Existing tests assume joined paragraphs]** → Audit `MarkdownRendererTests`
  and `MarkdownSyntaxCoverageTests`; update any assertion that depends on adjacent
  lines being joined by a space, and add explicit soft-break-`<br>` coverage. The
  existing `<br>` (hard-break) assertion must still pass.
- **[Accidental `<br>` across block boundaries]** → Block detection is untouched;
  `paragraphBlock` already stops at blank lines and block starters, so the final
  line of a paragraph correctly emits no trailing `<br>`.

## Migration Plan

Pure rendering change; no data migration. Rollback is reverting the one-line edit
in `paragraphHTML`. Verify by building the package and running the MD2Core tests,
plus a manual check of the reported blockquote sample in the app preview.
