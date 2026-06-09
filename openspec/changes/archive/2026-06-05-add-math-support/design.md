## Context

Markdown2 renders Markdown to HTML in `MarkdownRenderer` (`Sources/MD2Core`), and the Read mode displays that HTML in a `WKWebView` (`MarkdownPreviewView`). The preview already enables JavaScript and, for on-disk documents, loads the generated HTML from a temporary file via `loadFileURL(_:allowingReadAccessTo:)` granting read access to the document's directory. Syntax highlighting is done server-side in Swift and emitted as styled spans; there is currently no client-side rendering library involved.

Math is the highest-visibility missing feature versus the Typora reference. Typora uses MathJax; we need an equivalent that works **offline** (the app's preview model is local-file based, and releases are unsigned local apps with no guaranteed network).

## Goals / Non-Goals

**Goals:**
- Recognize inline `$...$` and block `$$...$$` TeX math in Markdown source.
- Typeset math in Read mode with correct, readable output that respects light/dark color scheme.
- Work fully offline with no runtime network calls.
- Keep math content literal: no Markdown inline processing, escaping, or HTML-escaping inside math spans.
- Avoid false positives on ordinary `$` usage (currency, escaped `\$`).

**Non-Goals:**
- Full MathJax feature parity (physics package, mhchem, `\label`/`\ref` cross-references, equation auto-numbering, `\def`/`\newcommand` macros) — these are Typora extras and out of scope for the first implementation.
- Live WYSIWYG inline typesetting inside the Write/editor surface (math stays as source text in edit mode).
- Export of typeset math to PDF/DOCX/etc.

## Decisions

### Decision 1: Rendering engine — KaTeX (bundled) over MathJax
- **Choice**: Bundle KaTeX (CSS + JS + fonts) as offline app resources and call `renderMathInElement` (KaTeX auto-render extension) on document load.
- **Why**: KaTeX is synchronous, fast, self-contained, and small enough to bundle; it renders without layout reflow flicker and ships a ready-made auto-render extension that scans for `$...$`/`$$...$$` delimiters. MathJax is larger, async, and historically heavier.
- **Alternatives considered**:
  - *MathJax (CDN)* — matches Typora exactly but requires network; rejected (offline requirement).
  - *MathJax (bundled)* — larger payload, async rendering, more moving parts; rejected for size/complexity.
  - *Server-side render in Swift* — no mature offline Swift TeX engine; rejected.

### Decision 2: Split responsibility — Swift detects, KaTeX typesets
- **Choice**: `MarkdownRenderer` is responsible for **detecting** math spans and emitting them into HTML in a form KaTeX can find, while KaTeX's auto-render does the actual typesetting in the browser.
- **Why**: Detection in Swift lets us protect math content from the normal inline pipeline (emphasis, links, HTML escaping, code detection) and gives us a single source of truth for what is and isn't math. We emit math into delimiter-preserving wrappers (e.g. a span/div whose text content is the raw TeX still wrapped in `$`/`$$`) and configure KaTeX auto-render to process them, OR we emit pre-classified elements and call `katex.render` per element.
- **Approach detail**: Prefer emitting wrapper elements that carry the raw TeX as escaped text content and let a small init script typeset them. Raw TeX must be HTML-escaped for safe transport (so `<`, `&`, `>` in TeX don't break the DOM) and then handed to KaTeX as its source string.
- **Alternative**: Let KaTeX auto-render scan the whole rendered body for `$` delimiters. Rejected as primary approach because already-rendered content (code blocks, prose containing `$`) could be mis-detected; doing detection in Swift is more precise and testable.

### Decision 3: Math takes precedence over inline Markdown, but not over code
- **Choice**: During inline parsing, scan for math delimiters with priority over emphasis/links, but **inline code** (`` `...` ``) and fenced/indented **code blocks** still win — `$x$` inside backticks or a code fence stays literal text.
- **Why**: Matches Typora/CommonMark-math conventions and avoids breaking documentation that shows literal `$` in code.

### Decision 4: Delimiter rules to avoid false positives
- Inline `$...$`: opening `$` must not be immediately followed by whitespace, closing `$` must not be immediately preceded by whitespace, and a `$` preceded by a backslash (`\$`) is a literal dollar sign, not a delimiter. An unmatched `$` on a line is literal.
- Block `$$...$$`: a line that is exactly `$$` opens/closes a display block; `$$ ... $$` on a single line is also a display block. Content spanning multiple lines is collected until the closing `$$`.
- **Why**: These mirror common Markdown-math implementations and prevent currency text (`$5 and $10`) from being captured.

### Decision 5: Offline asset bundling
- **Choice**: Add KaTeX assets under `Resources/` and declare them in `Package.swift` as bundle resources for the `MD2Core` (or app) target; inject `<link>`/`<script>` (or inlined CSS/JS) into `htmlDocument(body:)`.
- **Why**: The preview loads from a temp file in the document directory, so referencing bundle assets by relative path won't resolve. Either (a) inline the CSS/JS directly into the generated HTML `<head>` from the bundled resource strings, or (b) copy assets next to the temp preview file. Inlining is simplest and avoids extra read-access scoping; fonts can be embedded as base64 in CSS or copied alongside.
- **Trade-off**: Inlining increases generated HTML size; acceptable for a desktop preview.

## Risks / Trade-offs

- **[Bundle size grows]** → KaTeX + fonts add ~hundreds of KB. Mitigation: ship only required font formats (woff2), inline once.
- **[False positives on `$`]** → currency text rendered as math. Mitigation: strict delimiter rules (Decision 4) plus tests covering `$5`, `\$`, lone `$`.
- **[Math inside code blocks]** → `$x$` in code typeset by accident. Mitigation: detection respects code precedence (Decision 3) and KaTeX init is scoped to math wrapper elements only, not the whole body.
- **[Offline asset loading in WKWebView]** → relative asset URLs fail under `loadFileURL`. Mitigation: inline CSS/JS into generated HTML (Decision 5); verify in functional test.
- **[Dark mode legibility]** → KaTeX default color may clash. Mitigation: force math `color: currentColor` / inherit `--text`.
- **[Unsupported LaTeX command]** → KaTeX errors on commands outside its subset. Mitigation: configure KaTeX `throwOnError: false` so it shows the raw source in red instead of breaking the page.

## Migration Plan

Additive feature; no data migration. Rollback is removing the math detection branch and the injected assets. Behavior is gated only by the presence of `$`/`$$` delimiters in documents, so existing documents without math are unaffected.

## Open Questions

- Inline vs. copy for fonts: embed base64 in CSS or copy woff2 next to the preview temp file? (Lean: base64 inline for zero extra read-access scoping.)
- Should the editor (Write mode) apply any delimiter styling now, or defer entirely to a later change? (Lean: defer; keep scope to Read-mode typesetting.)
