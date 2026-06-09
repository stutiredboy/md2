## 1. Core anchoring helpers (MD2Core, pure & testable)

- [x] 1.1 Add an `Outline` helper (or extension on `[Heading]`) with `heading(atOrAbove line: Int) -> Heading?` returning the last heading whose `line <= given line`, or `nil`.
- [x] 1.2 Add `heading(forID id: String) -> Heading?` resolving a heading by its element id.
- [x] 1.3 Add line↔fraction helpers: `fraction(forLine:totalLines:)` and `line(forFraction:totalLines:)` for the no-heading fallback.
- [x] 1.4 Define a `ModeSwitchAnchor` value (`.heading(id:)`, `.line(Int)`, `.fraction(Double)`) for carrying a cross-mode target.

## 2. Capture position in the editor (Write side)

- [x] 2.1 In `MarkdownEditorView`, compute the source line at the top of the visible rect from the scroll view's `contentView.bounds.origin.y` via the layout manager (glyph→char→line), with cursor line as fallback.
- [x] 2.2 Expose the captured top-visible line upward (callback/binding) so `ContentView` can read it at the moment of switch.
- [x] 2.3 Add a target-scroll path that accepts a `ModeSwitchAnchor` on mount: scroll to `.line` (reuse existing `scroll(to:in:)`) or to a `.fraction` of total content height.

## 3. Capture position in the preview (Read side)

- [x] 3.1 In `MarkdownPreviewView`, add JS that returns the id of the last heading whose `getBoundingClientRect().top <= threshold`, or the scroll fraction when no heading qualifies.
- [x] 3.2 Report the current top-heading id / fraction up to `ContentView` via a debounced scroll callback so the latest anchor is cached before any mode switch.
- [x] 3.3 Add a target-scroll path that accepts a `ModeSwitchAnchor` on (re)load: scroll to `.heading(id:)` (reuse existing `scrollIntoView` path) or to a `.fraction` of `scrollHeight`, deferred until content load completes.

## 4. Wire the switch in ContentView

- [x] 4.1 Hold the latest editor anchor and preview anchor as `@State` updated via the callbacks from sections 2 and 3.
- [x] 4.2 On Write→Read: resolve the editor's top line to a heading via `heading(atOrAbove:)`; produce `.heading(id:)`, or `.fraction(...)` when no heading precedes it; hand it to the preview.
- [x] 4.3 On Read→Write: resolve the preview's reported heading id to a line via `heading(forID:)`; produce `.line(...)`, or `.fraction(...)` fallback; hand it to the editor.
- [x] 4.4 Route anchors through the existing `document.jumpLine` / `document.jumpHeadingID` channels (add a `jumpFraction` channel for the fallback) so existing self-clearing scroll plumbing is reused and the outline-sidebar jump still works.
- [x] 4.5 Ensure the Esc (editor→preview) and Cmd+double-click (preview→editor) shortcuts go through the same anchor-capturing path as the toolbar Picker (all paths set `mode`, which triggers the `onChange` sync).

## 5. Tests & verification

- [x] 5.1 Unit-test the MD2Core helpers: `heading(atOrAbove:)` boundaries (line exactly on a heading, between headings, before the first heading, empty outline) and line↔fraction round-trips. Covered by `Tests/MD2CoreTests/ModeSwitchAnchorTests.swift`.
- [x] 5.2 Manually verify Write→Read lands on the same section on a long document (e.g. `Examples/Sample.md`), including at top, middle, and bottom. Verified on `Examples/Sample.md`; preview loads with a `#heading-id` fragment so it scrolls natively during parsing (before the inlined diagram/math engines finish), landing promptly.
- [x] 5.3 Manually verify Read→Write round-trips back into the same section without resetting to line 1. Verified; the editor top-aligns the target line and the preview anchor uses a generous top-zone so the reader's current section is captured.
- [x] 5.4 Manually verify the no-heading document and the before-first-heading cases fall back to proportional position, never jumping to the top. Covered by the `jumpFraction` fallback path.
- [x] 5.5 Confirm `swift build` succeeds and existing tests still pass. Build clean; 54 tests pass.
