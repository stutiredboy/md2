import AppKit

enum MarkdownTextStyler {
    @MainActor
    static func apply(to textView: NSTextView) {
        guard let storage = textView.textStorage else { return }

        let fullRange = NSRange(location: 0, length: storage.length)
        let baseFont = NSFont.systemFont(ofSize: 16)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 7

        storage.beginEditing()
        storage.setAttributes([
            .font: baseFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ], range: fullRange)

        applyBlockStyles(to: storage)
        applyInlineStyles(to: storage)
        storage.endEditing()
    }

    private static func applyBlockStyles(to storage: NSTextStorage) {
        let source = storage.string
        var activeFence = false

        source.enumerateSubstrings(
            in: source.startIndex..<source.endIndex,
            options: [.byLines, .substringNotRequired]
        ) { _, substringRange, _, _ in
            let lineRange = NSRange(substringRange, in: source)
            let line = String(source[substringRange])
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                activeFence.toggle()
                addCodeLineStyle(to: storage, range: lineRange)
                return
            }

            if activeFence {
                addCodeLineStyle(to: storage, range: lineRange)
                return
            }

            if let headingLevel = headingLevel(in: trimmed) {
                let size = max(17, 30 - CGFloat(headingLevel * 3))
                storage.addAttributes([
                    .font: NSFont.boldSystemFont(ofSize: size),
                    .foregroundColor: NSColor.labelColor
                ], range: lineRange)
                return
            }

            if trimmed.hasPrefix(">") {
                storage.addAttributes([
                    .foregroundColor: NSColor.secondaryLabelColor
                ], range: lineRange)
            }

            if isListLine(trimmed), let markerRange = markerRange(in: line, lineRange: lineRange) {
                storage.addAttributes([
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
                ], range: markerRange)
            }
        }
    }

    private static func applyInlineStyles(to storage: NSTextStorage) {
        let string = storage.string
        let full = NSRange(string.startIndex..<string.endIndex, in: string)

        addRegexAttributes(
            to: storage,
            pattern: #"`[^`]+`"#,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: 15, weight: .regular),
                .backgroundColor: NSColor.textColor.withAlphaComponent(0.08)
            ],
            range: full
        )

        addRegexAttributes(
            to: storage,
            pattern: #"\*\*[^*]+\*\*|__[^_]+__"#,
            attributes: [
                .font: NSFont.boldSystemFont(ofSize: 16)
            ],
            range: full
        )

        addRegexAttributes(
            to: storage,
            pattern: #"(?<!\*)\*(?!\s)[^*]+(?<!\s)\*(?!\*)"#,
            attributes: [
                .font: NSFontManager.shared.convert(NSFont.systemFont(ofSize: 16), toHaveTrait: .italicFontMask)
            ],
            range: full
        )

        addRegexAttributes(
            to: storage,
            pattern: #"\[[^\]]+\]\([^)]+\)"#,
            attributes: [
                .foregroundColor: NSColor.linkColor
            ],
            range: full
        )
    }

    private static func addCodeLineStyle(to storage: NSTextStorage, range: NSRange) {
        storage.addAttributes([
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .backgroundColor: NSColor.textColor.withAlphaComponent(0.06)
        ], range: range)
    }

    private static func headingLevel(in trimmedLine: String) -> Int? {
        let count = trimmedLine.prefix { $0 == "#" }.count
        guard (1...6).contains(count), trimmedLine.dropFirst(count).first == " " else {
            return nil
        }
        return count
    }

    private static func isListLine(_ trimmedLine: String) -> Bool {
        if trimmedLine.hasPrefix("- ") || trimmedLine.hasPrefix("* ") || trimmedLine.hasPrefix("+ ") {
            return true
        }

        return trimmedLine.range(of: #"^\d+[\.)]\s+"#, options: .regularExpression) != nil
    }

    private static func markerRange(in line: String, lineRange: NSRange) -> NSRange? {
        if line.trimmingCharacters(in: .whitespaces).hasPrefix("- [ ] ") ||
            line.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("- [x] ") {
            return NSRange(location: lineRange.location, length: min(6, lineRange.length))
        }

        if let range = line.range(of: #"^\s*(?:[-*+]|\d+[\.)])\s+"#, options: .regularExpression) {
            let nsRange = NSRange(range, in: line)
            return NSRange(location: lineRange.location + nsRange.location, length: nsRange.length)
        }

        return nil
    }

    private static func addRegexAttributes(
        to storage: NSTextStorage,
        pattern: String,
        attributes: [NSAttributedString.Key: Any],
        range: NSRange
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return
        }

        let string = storage.string
        regex.enumerateMatches(in: string, range: range) { match, _, _ in
            guard let match else { return }
            storage.addAttributes(attributes, range: match.range)
        }
    }
}
