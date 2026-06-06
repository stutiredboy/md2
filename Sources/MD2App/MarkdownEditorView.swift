import AppKit
import SwiftUI

struct MarkdownEditorView: NSViewRepresentable {
    @Binding var text: String
    @Binding var jumpLine: Int?
    /// Fraction (0...1) to scroll to on mount when no line anchor applies.
    @Binding var jumpFraction: Double?
    /// Reports the source line at the top of the visible rect whenever the user
    /// scrolls, so the surrounding view can anchor a mode switch to it.
    var onAnchorLineChange: (Int) -> Void = { _ in }
    /// Called when the user presses Esc, requesting a switch to preview mode.
    var onEnterPreview: () -> Void = {}

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.autohidesScrollers = true

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.string = text
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isContinuousSpellCheckingEnabled = true
        textView.textContainerInset = NSSize(width: 58, height: 48)
        textView.backgroundColor = .textBackgroundColor
        textView.drawsBackground = true
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: scrollView.contentSize.width, height: .greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]
        textView.minSize = NSSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false

        MarkdownTextStyler.apply(to: textView)

        scrollView.documentView = textView

        // Observe scrolling so the top visible line can anchor a mode switch.
        let clipView = scrollView.contentView
        clipView.postsBoundsChangedNotifications = true
        context.coordinator.observe(scrollView: scrollView)

        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.onEnterPreview = onEnterPreview
        context.coordinator.onAnchorLineChange = onAnchorLineChange
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.string != text, !context.coordinator.isApplyingStyle {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            MarkdownTextStyler.apply(to: textView)
            textView.selectedRanges = selectedRanges
        }

        if let jumpLine {
            DispatchQueue.main.async {
                scroll(to: jumpLine, in: textView)
                self.jumpLine = nil
                self.jumpFraction = nil
            }
        } else if let jumpFraction {
            DispatchQueue.main.async {
                scroll(toFraction: jumpFraction, in: scrollView)
                self.jumpFraction = nil
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(text: $text)
        coordinator.onEnterPreview = onEnterPreview
        coordinator.onAnchorLineChange = onAnchorLineChange
        return coordinator
    }

    /// Scrolls the editor to a vertical fraction (0...1) of its content. Used as
    /// the fallback when no source-line anchor is available.
    private func scroll(toFraction fraction: Double, in scrollView: NSScrollView) {
        guard let documentView = scrollView.documentView else { return }
        let clamped = min(max(fraction, 0), 1)
        let visibleHeight = scrollView.contentView.bounds.height
        let maxOffset = max(0, documentView.bounds.height - visibleHeight)
        let targetY = maxOffset * CGFloat(clamped)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: targetY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func scroll(to line: Int, in textView: NSTextView) {
        let lineIndex = max(1, line)
        let string = textView.string as NSString
        var currentLine = 1
        var location = 0

        while currentLine < lineIndex, location < string.length {
            let range = string.range(of: "\n", options: [], range: NSRange(location: location, length: string.length - location))
            if range.location == NSNotFound {
                break
            }
            location = range.location + 1
            currentLine += 1
        }

        let targetRange = NSRange(location: min(location, string.length), length: 0)
        textView.setSelectedRange(targetRange)
        scrollLineToTop(charRange: targetRange, in: textView)
        textView.window?.makeFirstResponder(textView)
    }

    /// Scrolls so the given character range sits near the top of the visible
    /// area (matching how the preview places a heading at the top), rather than
    /// `scrollRangeToVisible`, which only scrolls the minimum amount and leaves
    /// a target below the fold sitting at the bottom. Layout is forced first so
    /// the geometry is valid even on a freshly created text view.
    private func scrollLineToTop(charRange: NSRange, in textView: NSTextView) {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let scrollView = textView.enclosingScrollView else {
            textView.scrollRangeToVisible(charRange)
            return
        }

        layoutManager.ensureLayout(for: textContainer)
        let glyphRange = layoutManager.glyphRange(forCharacterRange: charRange, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        // Convert from text-container coordinates to the text view (document)
        // coordinate space the clip view scrolls in.
        let origin = textView.textContainerOrigin
        rect.origin.y += origin.y

        let documentHeight = textView.bounds.height
        let visibleHeight = scrollView.contentView.bounds.height
        let maxOffset = max(0, documentHeight - visibleHeight)
        // Leave a small top margin (the container inset) so the line is not
        // flush against the very top edge.
        let targetY = min(max(0, rect.minY - origin.y), maxOffset)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: targetY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        var isApplyingStyle = false
        var onEnterPreview: () -> Void = {}
        var onAnchorLineChange: (Int) -> Void = { _ in }
        private weak var scrollView: NSScrollView?

        init(text: Binding<String>) {
            _text = text
        }

        /// Registers for the clip view's bounds-change notifications so the top
        /// visible source line is reported on every scroll.
        @MainActor func observe(scrollView: NSScrollView) {
            self.scrollView = scrollView
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(boundsDidChange),
                name: NSView.boundsDidChangeNotification,
                object: scrollView.contentView
            )
        }

        @MainActor @objc private func boundsDidChange() {
            guard let scrollView,
                  let line = Self.topVisibleLine(in: scrollView) else { return }
            onAnchorLineChange(line)
        }

        /// Computes the 1-based source line at the top of the visible rect using
        /// the layout manager (bounding rect → glyph range → character → line).
        @MainActor static func topVisibleLine(in scrollView: NSScrollView) -> Int? {
            guard let textView = scrollView.documentView as? NSTextView,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return nil }

            // `glyphRange(forBoundingRect:)` expects the rect in container
            // coordinates, which differ from the text view's by the container
            // origin (the text container inset).
            var rect = textView.visibleRect
            let origin = textView.textContainerOrigin
            rect.origin.x -= origin.x
            rect.origin.y -= origin.y
            layoutManager.ensureLayout(for: textContainer)
            let glyphRange = layoutManager.glyphRange(forBoundingRect: rect, in: textContainer)
            let charIndex = layoutManager.characterIndexForGlyph(at: glyphRange.location)

            let string = textView.string as NSString
            let clampedIndex = min(charIndex, string.length)
            // Line number = newlines before the index + 1, matching scroll(to:).
            var line = 1
            var location = 0
            while location < clampedIndex {
                let range = string.range(
                    of: "\n",
                    options: [],
                    range: NSRange(location: location, length: clampedIndex - location)
                )
                if range.location == NSNotFound { break }
                line += 1
                location = range.location + 1
            }
            return line
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            // Esc maps to cancelOperation: in the standard key bindings. Intercept
            // it here so the editor switches to preview instead of triggering the
            // text view's default completion behaviour.
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                onEnterPreview()
                return true
            }
            return false
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string

            let selectedRanges = textView.selectedRanges
            isApplyingStyle = true
            MarkdownTextStyler.apply(to: textView)
            isApplyingStyle = false
            textView.selectedRanges = selectedRanges
        }
    }
}
