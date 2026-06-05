import Foundation

public struct MarkdownRenderer: Sendable {
    private let outlineBuilder = OutlineBuilder()

    public init() {}

    public func render(_ markdown: String) -> RenderedDocument {
        let outline = outlineBuilder.build(from: markdown)
        let body = renderBody(markdown, outline: outline)
        let html = htmlDocument(body: body)

        return RenderedDocument(
            html: html,
            outline: outline,
            stats: DocumentStats(markdown: markdown)
        )
    }

    private func renderBody(_ markdown: String, outline: [Heading]) -> String {
        let lines = markdown.normalizedMarkdownLines
        let headingsByLine = Dictionary(uniqueKeysWithValues: outline.map { ($0.line, $0) })
        var blocks: [String] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmedMarkdownLine

            if trimmed.isEmpty {
                index += 1
                continue
            }

            if index == 0, trimmed == "---" {
                if let frontMatter = frontMatterBlock(from: lines, startIndex: index) {
                    blocks.append(frontMatter.html)
                    index = frontMatter.nextIndex
                    continue
                }
            }

            if let fence = fencedCodeBlock(from: lines, startIndex: index) {
                blocks.append(fence.html)
                index = fence.nextIndex
                continue
            }

            if let indentedCode = indentedCodeBlock(from: lines, startIndex: index) {
                blocks.append(indentedCode.html)
                index = indentedCode.nextIndex
                continue
            }

            if let math = mathBlock(from: lines, startIndex: index) {
                blocks.append(math.html)
                index = math.nextIndex
                continue
            }

            if trimmed == "[TOC]" {
                blocks.append(tableOfContents(outline))
                index += 1
                continue
            }

            if let table = tableBlock(from: lines, startIndex: index) {
                blocks.append(table.html)
                index = table.nextIndex
                continue
            }

            if let setextHeading = setextHeadingBlock(from: lines, startIndex: index, headingsByLine: headingsByLine) {
                blocks.append(setextHeading.html)
                index = setextHeading.nextIndex
                continue
            }

            if let heading = MarkdownLine.heading(in: line), let outlineHeading = headingsByLine[index + 1] {
                blocks.append(
                    "<h\(heading.level) id=\"\(escapeAttribute(outlineHeading.id))\">\(inlineHTML(heading.title))</h\(heading.level)>"
                )
                index += 1
                continue
            }

            if MarkdownLine.isHorizontalRule(line) {
                blocks.append("<hr>")
                index += 1
                continue
            }

            if trimmed.hasPrefix(">") {
                let blockquote = blockquoteBlock(from: lines, startIndex: index)
                blocks.append(blockquote.html)
                index = blockquote.nextIndex
                continue
            }

            if let list = listBlock(from: lines, startIndex: index) {
                blocks.append(list.html)
                index = list.nextIndex
                continue
            }

            let paragraph = paragraphBlock(from: lines, startIndex: index)
            blocks.append(paragraph.html)
            index = paragraph.nextIndex
        }

        return blocks.joined(separator: "\n")
    }

    private func frontMatterBlock(from lines: [String], startIndex: Int) -> (html: String, nextIndex: Int)? {
        guard lines[startIndex].trimmedMarkdownLine == "---" else { return nil }

        var index = startIndex + 1
        var content: [String] = []

        while index < lines.count {
            if lines[index].trimmedMarkdownLine == "---" {
                return (
                    "<pre class=\"front-matter\"><code>\(escapeHTML(content.joined(separator: "\n")))</code></pre>",
                    index + 1
                )
            }

            content.append(lines[index])
            index += 1
        }

        return nil
    }

    private func fencedCodeBlock(from lines: [String], startIndex: Int) -> (html: String, nextIndex: Int)? {
        guard let marker = MarkdownLine.fenceMarker(in: lines[startIndex]) else { return nil }

        let opening = lines[startIndex].trimmedMarkdownLine
        let language = opening
            .dropFirst(marker.count)
            .trimmingCharacters(in: .whitespaces)
        var code: [String] = []
        var index = startIndex + 1

        while index < lines.count {
            if lines[index].trimmedMarkdownLine.hasPrefix(marker) {
                let languageClass = language.isEmpty ? "" : " class=\"language-\(escapeAttribute(language))\""
                return (
                    "<pre><code\(languageClass)>\(SyntaxHighlighter.highlightedHTML(for: code.joined(separator: "\n"), language: language))</code></pre>",
                    index + 1
                )
            }

            code.append(lines[index])
            index += 1
        }

        let languageClass = language.isEmpty ? "" : " class=\"language-\(escapeAttribute(language))\""
        return (
            "<pre><code\(languageClass)>\(SyntaxHighlighter.highlightedHTML(for: code.joined(separator: "\n"), language: language))</code></pre>",
            index
        )
    }

    private func indentedCodeBlock(from lines: [String], startIndex: Int) -> (html: String, nextIndex: Int)? {
        guard MarkdownLine.isIndentedCode(lines[startIndex]) else { return nil }

        var code: [String] = []
        var index = startIndex

        while index < lines.count {
            let line = lines[index]
            if line.trimmedMarkdownLine.isEmpty {
                code.append("")
                index += 1
                continue
            }

            guard MarkdownLine.isIndentedCode(line) else {
                break
            }

            code.append(MarkdownLine.stripCodeIndent(line))
            index += 1
        }

        return ("<pre><code>\(escapeHTML(code.joined(separator: "\n")))</code></pre>", index)
    }

    /// Detects a display math block delimited by `$$`.
    ///
    /// Handles both a single line such as `$$a^2 + b^2 = c^2$$` and a multi-line
    /// block whose opening line starts with `$$` and whose content runs until a
    /// line ending in `$$`. Returns `nil` when there is no closing `$$`, so the
    /// text falls through to normal paragraph handling.
    private func mathBlock(from lines: [String], startIndex: Int) -> (html: String, nextIndex: Int)? {
        let trimmed = lines[startIndex].trimmedMarkdownLine
        guard trimmed.hasPrefix("$$") else { return nil }

        let afterOpen = String(trimmed.dropFirst(2))

        // Single-line block: `$$ ... $$`
        if afterOpen.hasSuffix("$$"), afterOpen.count >= 2 {
            let inner = String(afterOpen.dropLast(2))
            return (mathDisplayHTML(inner), startIndex + 1)
        }

        // Multi-line block: collect lines until one ends with `$$`.
        var content: [String] = []
        if !afterOpen.isEmpty {
            content.append(afterOpen)
        }

        var index = startIndex + 1
        while index < lines.count {
            let lineTrimmed = lines[index].trimmedMarkdownLine
            if lineTrimmed.hasSuffix("$$") {
                let beforeClose = String(lineTrimmed.dropLast(2))
                if !beforeClose.isEmpty {
                    content.append(beforeClose)
                }
                return (mathDisplayHTML(content.joined(separator: "\n")), index + 1)
            }

            content.append(lines[index])
            index += 1
        }

        return nil
    }

    /// Emits a display-math wrapper carrying the raw TeX as HTML-escaped text
    /// content so the math engine can read it verbatim from the DOM.
    private func mathDisplayHTML(_ tex: String) -> String {
        "<div class=\"math math-display\">\(escapeHTML(tex.trimmingCharacters(in: .whitespacesAndNewlines)))</div>"
    }

    private func setextHeadingBlock(
        from lines: [String],
        startIndex: Int,
        headingsByLine: [Int: Heading]
    ) -> (html: String, nextIndex: Int)? {
        guard startIndex + 1 < lines.count,
              let level = MarkdownLine.setextHeadingLevel(in: lines[startIndex + 1]) else {
            return nil
        }

        let title = lines[startIndex].trimmedMarkdownLine
        guard !title.isEmpty,
              MarkdownLine.heading(in: lines[startIndex]) == nil,
              MarkdownLine.fenceMarker(in: lines[startIndex]) == nil,
              !MarkdownLine.isHorizontalRule(lines[startIndex]),
              parseListItem(lines[startIndex]) == nil,
              !lines[startIndex].trimmedMarkdownLine.hasPrefix(">") else {
            return nil
        }

        var fallbackSlugs: [String: Int] = [:]
        let heading = headingsByLine[startIndex + 1]
        let id = heading?.id ?? Slugger.uniqueSlug(for: title, usedSlugs: &fallbackSlugs)
        return (
            "<h\(level) id=\"\(escapeAttribute(id))\">\(inlineHTML(title))</h\(level)>",
            startIndex + 2
        )
    }

    private func tableBlock(from lines: [String], startIndex: Int) -> (html: String, nextIndex: Int)? {
        guard startIndex + 1 < lines.count,
              lines[startIndex].contains("|"),
              let alignments = tableAlignments(in: lines[startIndex + 1]) else {
            return nil
        }

        let headers = splitTableLine(lines[startIndex])
        guard !headers.isEmpty else { return nil }

        var rows: [[String]] = []
        var index = startIndex + 2

        while index < lines.count, lines[index].contains("|"), !lines[index].trimmedMarkdownLine.isEmpty {
            rows.append(splitTableLine(lines[index]))
            index += 1
        }

        let headerHTML = headers.enumerated()
            .map { index, header in
                let style = alignments[safe: index]?.htmlAttribute ?? ""
                return "<th\(style)>\(inlineHTML(header.trimmingCharacters(in: .whitespaces)))</th>"
            }
            .joined()
        let bodyHTML = rows
            .map { row in
                let cells = row.enumerated()
                    .map { index, cell in
                        let style = alignments[safe: index]?.htmlAttribute ?? ""
                        return "<td\(style)>\(inlineHTML(cell.trimmingCharacters(in: .whitespaces)))</td>"
                    }
                    .joined()
                return "<tr>\(cells)</tr>"
            }
            .joined(separator: "\n")

        return (
            """
            <table>
            <thead><tr>\(headerHTML)</tr></thead>
            <tbody>
            \(bodyHTML)
            </tbody>
            </table>
            """,
            index
        )
    }

    private func blockquoteBlock(from lines: [String], startIndex: Int) -> (html: String, nextIndex: Int) {
        var quoteLines: [String] = []
        var index = startIndex

        while index < lines.count {
            let trimmed = lines[index].trimmedMarkdownLine
            guard trimmed.hasPrefix(">") else { break }

            let content = trimmed.dropFirst().trimmingCharacters(in: .whitespaces)
            quoteLines.append(String(content))
            index += 1
        }

        let nestedMarkdown = quoteLines.joined(separator: "\n")
        let quote = renderBody(nestedMarkdown, outline: outlineBuilder.build(from: nestedMarkdown))

        return ("<blockquote>\n\(quote)\n</blockquote>", index)
    }

    private func listBlock(from lines: [String], startIndex: Int) -> (html: String, nextIndex: Int)? {
        guard let firstItem = parseListItem(lines[startIndex]) else { return nil }

        var items: [ListItem] = [firstItem]
        var index = startIndex + 1

        while index < lines.count, let item = parseListItem(lines[index]) {
            guard item.kind == firstItem.kind else { break }
            items.append(item)
            index += 1
        }

        let tag = firstItem.kind == .ordered ? "ol" : "ul"
        let className = items.contains { $0.checked != nil } ? " class=\"task-list\"" : ""
        let itemHTML = items.map { item in
            let checkbox: String
            if let checked = item.checked {
                checkbox = "<input type=\"checkbox\" disabled\(checked ? " checked" : "")> "
            } else {
                checkbox = ""
            }

            return "<li>\(checkbox)\(inlineHTML(item.text))</li>"
        }.joined(separator: "\n")

        return ("<\(tag)\(className)>\n\(itemHTML)\n</\(tag)>", index)
    }

    private func paragraphBlock(from lines: [String], startIndex: Int) -> (html: String, nextIndex: Int) {
        var paragraphLines: [String] = []
        var index = startIndex

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmedMarkdownLine

            if trimmed.isEmpty ||
                MarkdownLine.heading(in: line) != nil ||
                MarkdownLine.fenceMarker(in: line) != nil ||
                MarkdownLine.isHorizontalRule(line) ||
                (index + 1 < lines.count && MarkdownLine.setextHeadingLevel(in: lines[index + 1]) != nil) ||
                trimmed == "[TOC]" ||
                trimmed.hasPrefix(">") ||
                parseListItem(line) != nil ||
                mathBlock(from: lines, startIndex: index) != nil ||
                tableBlock(from: lines, startIndex: index) != nil {
                break
            }

            paragraphLines.append(line)
            index += 1
        }

        return ("<p>\(paragraphHTML(paragraphLines))</p>", max(index, startIndex + 1))
    }

    private func paragraphHTML(_ lines: [String]) -> String {
        lines.enumerated().map { index, line in
            let hasHardBreak = line.hasSuffix("  ") || line.hasSuffix("\\")
            let content: String

            if line.hasSuffix("\\") {
                content = String(line.dropLast()).trimmingCharacters(in: .whitespaces)
            } else {
                content = line.trimmingCharacters(in: .whitespaces)
            }

            if hasHardBreak {
                return "\(inlineHTML(content))<br>"
            }

            if index < lines.count - 1 {
                return "\(inlineHTML(content)) "
            }

            return inlineHTML(content)
        }.joined()
    }

    private func tableOfContents(_ outline: [Heading]) -> String {
        guard !outline.isEmpty else { return "<nav class=\"toc\"></nav>" }

        let items = outline.map { heading in
            """
            <a class="toc-level-\(heading.level)" href="#\(escapeAttribute(heading.id))">\(escapeHTML(heading.title))</a>
            """
        }.joined(separator: "\n")

        return "<nav class=\"toc\">\n\(items)\n</nav>"
    }

    private func parseListItem(_ line: String) -> ListItem? {
        let trimmed = line.trimmedMarkdownLine

        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
            var text = String(trimmed.dropFirst(2))
            var checked: Bool?

            if text.lowercased().hasPrefix("[x] ") {
                checked = true
                text = String(text.dropFirst(4))
            } else if text.hasPrefix("[ ] ") {
                checked = false
                text = String(text.dropFirst(4))
            }

            return ListItem(kind: .unordered, checked: checked, text: text)
        }

        guard let match = firstMatch(in: trimmed, pattern: #"^\d+[\.)]\s+(.+)$"#),
              let textRange = Range(match.range(at: 1), in: trimmed) else {
            return nil
        }

        return ListItem(kind: .ordered, checked: nil, text: String(trimmed[textRange]))
    }

    private func tableAlignments(in line: String) -> [TableAlignment]? {
        let cells = splitTableLine(line)
        guard !cells.isEmpty else { return nil }

        var alignments: [TableAlignment] = []

        for cell in cells {
            let trimmed = cell.trimmingCharacters(in: .whitespaces)
            guard trimmed.range(of: #"^:?-{3,}:?$"#, options: .regularExpression) != nil else {
                return nil
            }

            if trimmed.hasPrefix(":"), trimmed.hasSuffix(":") {
                alignments.append(.center)
            } else if trimmed.hasSuffix(":") {
                alignments.append(.right)
            } else {
                alignments.append(.left)
            }
        }

        return alignments
    }

    private func splitTableLine(_ line: String) -> [String] {
        var trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.first == "|" {
            trimmed.removeFirst()
        }

        if trimmed.last == "|" {
            trimmed.removeLast()
        }

        var cells: [String] = []
        var current = ""
        var isEscaped = false
        var activeBacktickCount = 0

        for character in trimmed {
            if isEscaped {
                current.append(character)
                isEscaped = false
                continue
            }

            if character == "\\" {
                current.append(character)
                isEscaped = true
                continue
            }

            if character == "`" {
                activeBacktickCount = activeBacktickCount == 0 ? 1 : 0
                current.append(character)
                continue
            }

            if character == "|", activeBacktickCount == 0 {
                cells.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }

        cells.append(current)
        return cells
    }

    private func inlineHTML(_ markdown: String) -> String {
        var protectedFragments: [String] = []
        func protect(_ fragment: String) -> String {
            let token = "\u{E000}MD2-\(protectedFragments.count)\u{E000}"
            protectedFragments.append(fragment)
            return token
        }

        var text = replaceMatches(in: markdown, pattern: #"`([^`]+)`"#) { match, source in
            guard let codeRange = Range(match.range(at: 1), in: source) else {
                return matchText(match, in: source)
            }

            return protect("<code>\(escapeHTML(String(source[codeRange])))</code>")
        }

        text = replaceMatches(in: text, pattern: ##"\\([!"#$%&'()*+,\-./:;<=>?@\[\]\\^_`{|}~])"##) { match, source in
            guard let escapedRange = Range(match.range(at: 1), in: source) else {
                return matchText(match, in: source)
            }

            return protect(escapeHTML(String(source[escapedRange])))
        }

        // Inline math: `$...$`. Runs after code and backslash-escape protection so
        // `$` inside code or an escaped `\$` is never treated as a delimiter. The
        // opening `$` must not be followed by whitespace, the closing `$` must not
        // be preceded by whitespace, and `$$` (display math) is excluded.
        text = replaceMatches(in: text, pattern: #"(?<!\$)\$(?![\s$])((?:[^$])+?)(?<!\s)\$(?!\$)"#) { match, source in
            guard let range = Range(match.range(at: 1), in: source) else {
                return matchText(match, in: source)
            }

            return protect("<span class=\"math math-inline\">\(escapeHTML(String(source[range])))</span>")
        }

        text = replaceMatches(in: text, pattern: #"&(?:#\d+|#x[0-9A-Fa-f]+|[A-Za-z][A-Za-z0-9]+);"#) { match, source in
            protect(matchText(match, in: source))
        }

        text = replaceMatches(in: text, pattern: #"<((?:https?|mailto):[^>\s]+)>"#) { match, source in
            guard let urlRange = Range(match.range(at: 1), in: source) else {
                return matchText(match, in: source)
            }

            let url = String(source[urlRange])
            return protect("<a href=\"\(escapeAttribute(url))\">\(escapeHTML(url))</a>")
        }

        text = replaceMatches(in: text, pattern: #"</?(?:abbr|b|br|cite|code|del|details|div|em|i|img|kbd|mark|small|span|strong|sub|summary|sup|u)(?:\s+[^<>]*)?/?>"#) { match, source in
            protect(matchText(match, in: source))
        }

        text = escapeHTML(text)

        text = replaceMatches(in: text, pattern: #"\*\*\*(.+?)\*\*\*"#) { match, source in
            guard let range = Range(match.range(at: 1), in: source) else { return matchText(match, in: source) }
            return "<strong><em>\(source[range])</em></strong>"
        }

        text = replaceMatches(in: text, pattern: #"___(.+?)___"#) { match, source in
            guard let range = Range(match.range(at: 1), in: source) else { return matchText(match, in: source) }
            return "<strong><em>\(source[range])</em></strong>"
        }

        text = replaceMatches(in: text, pattern: #"~~(.+?)~~"#) { match, source in
            guard let range = Range(match.range(at: 1), in: source) else { return matchText(match, in: source) }
            return "<del>\(source[range])</del>"
        }

        text = replaceMatches(in: text, pattern: #"\*\*(.+?)\*\*"#) { match, source in
            guard let range = Range(match.range(at: 1), in: source) else { return matchText(match, in: source) }
            return "<strong>\(source[range])</strong>"
        }

        text = replaceMatches(in: text, pattern: #"__(.+?)__"#) { match, source in
            guard let range = Range(match.range(at: 1), in: source) else { return matchText(match, in: source) }
            return "<strong>\(source[range])</strong>"
        }

        text = replaceMatches(in: text, pattern: #"(?<!\*)\*(?!\s)(.+?)(?<!\s)\*(?!\*)"#) { match, source in
            guard let range = Range(match.range(at: 1), in: source) else { return matchText(match, in: source) }
            return "<em>\(source[range])</em>"
        }

        text = replaceMatches(in: text, pattern: #"(?<!_)_(?!\s)(.+?)(?<!\s)_(?!_)"#) { match, source in
            guard let range = Range(match.range(at: 1), in: source) else { return matchText(match, in: source) }
            return "<em>\(source[range])</em>"
        }

        text = replaceMatches(in: text, pattern: #"!\[([^\]]*)\]\((\S+?)(?:\s+&quot;(.+?)&quot;)?\)"#) { match, source in
            guard let altRange = Range(match.range(at: 1), in: source),
                  let srcRange = Range(match.range(at: 2), in: source) else {
                return matchText(match, in: source)
            }

            let title: String
            if match.range(at: 3).location != NSNotFound, let titleRange = Range(match.range(at: 3), in: source) {
                title = " title=\"\(source[titleRange])\""
            } else {
                title = ""
            }

            return "<img src=\"\(source[srcRange])\" alt=\"\(source[altRange])\"\(title)>"
        }

        text = replaceMatches(in: text, pattern: #"\[([^\]]+)\]\((\S+?)(?:\s+&quot;(.+?)&quot;)?\)"#) { match, source in
            guard let labelRange = Range(match.range(at: 1), in: source),
                  let hrefRange = Range(match.range(at: 2), in: source) else {
                return matchText(match, in: source)
            }

            let title: String
            if match.range(at: 3).location != NSNotFound, let titleRange = Range(match.range(at: 3), in: source) {
                title = " title=\"\(source[titleRange])\""
            } else {
                title = ""
            }

            return "<a href=\"\(source[hrefRange])\"\(title)>\(source[labelRange])</a>"
        }

        for (index, fragment) in protectedFragments.enumerated() {
            text = text.replacingOccurrences(of: "\u{E000}MD2-\(index)\u{E000}", with: fragment)
        }

        return text
    }

    private func htmlDocument(body: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        \(MathAssets.css)
        </style>
        <style>
        :root {
            color-scheme: light dark;
            --text: light-dark(#1f2328, #f3f4f6);
            --muted: light-dark(#6b7280, #a1a1aa);
            --border: light-dark(#d8dee4, #3f3f46);
            --code-bg: light-dark(#f6f8fa, #27272a);
            --quote-bg: light-dark(#fbfbfc, #202024);
            --accent: light-dark(#2563eb, #60a5fa);
            --page: light-dark(#ffffff, #18181b);
        }

        html {
            background: var(--page);
        }

        body {
            margin: 0;
            color: var(--text);
            background: var(--page);
            font: 16px/1.68 -apple-system, BlinkMacSystemFont, "SF Pro Text", "Helvetica Neue", sans-serif;
        }

        main {
            box-sizing: border-box;
            width: min(100%, 860px);
            margin: 0 auto;
            padding: 52px 58px 80px;
        }

        h1, h2, h3, h4, h5, h6 {
            line-height: 1.25;
            margin: 1.35em 0 0.55em;
            letter-spacing: 0;
        }

        h1 {
            font-size: 2.15rem;
            border-bottom: 1px solid var(--border);
            padding-bottom: 0.28em;
        }

        h2 {
            font-size: 1.58rem;
            border-bottom: 1px solid var(--border);
            padding-bottom: 0.22em;
        }

        h3 { font-size: 1.24rem; }
        h4 { font-size: 1.08rem; }
        h5, h6 { font-size: 1rem; color: var(--muted); }

        p, ul, ol, blockquote, pre, table {
            margin: 0.85em 0;
        }

        a {
            color: var(--accent);
            text-decoration: none;
        }

        a:hover {
            text-decoration: underline;
        }

        code {
            background: var(--code-bg);
            border-radius: 5px;
            font-family: "SF Mono", Menlo, Consolas, monospace;
            font-size: 0.9em;
            padding: 0.12em 0.34em;
        }

        pre {
            background: var(--code-bg);
            border-radius: 8px;
            overflow-x: auto;
            padding: 16px 18px;
        }

        pre code {
            display: block;
            background: transparent;
            border-radius: 0;
            padding: 0;
            white-space: pre;
        }

        .tok-keyword { color: light-dark(#9d174d, #f472b6); font-weight: 650; }
        .tok-type { color: light-dark(#0f766e, #5eead4); font-weight: 600; }
        .tok-string { color: light-dark(#166534, #86efac); }
        .tok-number { color: light-dark(#7c3aed, #c4b5fd); }
        .tok-comment { color: var(--muted); font-style: italic; }
        .tok-function { color: light-dark(#1d4ed8, #93c5fd); }

        blockquote {
            color: var(--muted);
            background: var(--quote-bg);
            border-left: 4px solid var(--border);
            padding: 0.45em 1em;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            display: block;
            overflow-x: auto;
        }

        th, td {
            border: 1px solid var(--border);
            padding: 8px 10px;
            text-align: left;
        }

        th {
            background: var(--code-bg);
            font-weight: 650;
        }

        img {
            display: block;
            max-width: 100%;
            height: auto;
            margin: 1.1em auto;
        }

        hr {
            border: 0;
            border-top: 1px solid var(--border);
            margin: 2em 0;
        }

        .front-matter {
            color: var(--muted);
        }

        .toc {
            border: 1px solid var(--border);
            border-radius: 8px;
            padding: 14px 16px;
            margin: 1em 0 1.4em;
        }

        .toc a {
            display: block;
            line-height: 1.8;
        }

        .toc-level-2 { padding-left: 16px; }
        .toc-level-3 { padding-left: 32px; }
        .toc-level-4 { padding-left: 48px; }
        .toc-level-5 { padding-left: 64px; }
        .toc-level-6 { padding-left: 80px; }

        .task-list {
            list-style: none;
            padding-left: 0;
        }

        .task-list input {
            margin-right: 0.45em;
        }

        /* Typeset math inherits the preview foreground color for light/dark legibility. */
        .katex { color: var(--text); }
        .math-display {
            overflow-x: auto;
            overflow-y: hidden;
            margin: 1em 0;
            text-align: center;
        }
        .math-error {
            color: light-dark(#b91c1c, #f87171);
            font-family: "SF Mono", Menlo, Consolas, monospace;
            font-size: 0.9em;
        }

        @media (max-width: 720px) {
            main {
                padding: 32px 24px 60px;
            }
        }
        </style>
        </head>
        <body>
        <main>
        \(body)
        </main>
        <script>
        \(MathAssets.javaScript)
        </script>
        <script>
        \(MathAssets.mhchem)
        </script>
        <script>
        (function () {
            if (typeof katex === "undefined") { return; }
            var nodes = document.querySelectorAll(".math-inline, .math-display");
            for (var i = 0; i < nodes.length; i++) {
                var el = nodes[i];
                var tex = el.textContent;
                var display = el.classList.contains("math-display");
                try {
                    katex.render(tex, el, { displayMode: display, throwOnError: false });
                } catch (err) {
                    el.classList.add("math-error");
                    el.textContent = tex;
                }
            }
        })();
        </script>
        </body>
        </html>
        """
    }

    private func replaceMatches(
        in source: String,
        pattern: String,
        transform: (NSTextCheckingResult, String) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return source
        }

        let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
        let matches = regex.matches(in: source, range: nsRange)
        var result = source

        for match in matches.reversed() {
            guard let range = Range(match.range, in: result) else { continue }
            result.replaceSubrange(range, with: transform(match, result))
        }

        return result
    }

    private func firstMatch(in source: String, pattern: String) -> NSTextCheckingResult? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        return regex.firstMatch(
            in: source,
            range: NSRange(source.startIndex..<source.endIndex, in: source)
        )
    }

    private func matchText(_ match: NSTextCheckingResult, in source: String) -> String {
        guard let range = Range(match.range, in: source) else { return "" }
        return String(source[range])
    }

    private func escapeHTML(_ source: String) -> String {
        source
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func escapeAttribute(_ source: String) -> String {
        escapeHTML(source)
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

private struct ListItem {
    let kind: ListKind
    let checked: Bool?
    let text: String
}

private enum ListKind: Equatable {
    case unordered
    case ordered
}

private enum TableAlignment {
    case left
    case center
    case right

    var htmlAttribute: String {
        switch self {
        case .left:
            return #" style="text-align:left""#
        case .center:
            return #" style="text-align:center""#
        case .right:
            return #" style="text-align:right""#
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
