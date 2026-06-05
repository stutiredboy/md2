import Foundation

enum MarkdownLine {
    static func heading(in line: String) -> (level: Int, title: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let level = trimmed.prefix { $0 == "#" }.count

        guard (1...6).contains(level) else { return nil }
        let afterHashes = trimmed.dropFirst(level)
        guard afterHashes.first == " " else { return nil }

        let rawTitle = afterHashes
            .dropFirst()
            .trimmingCharacters(in: .whitespaces)

        guard !rawTitle.isEmpty else { return nil }

        let cleanedTitle = rawTitle.replacingOccurrences(
            of: #"\s+#+\s*$"#,
            with: "",
            options: .regularExpression
        )

        return (level, cleanedTitle)
    }

    static func fenceMarker(in line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("```") {
            return "```"
        }

        if trimmed.hasPrefix("~~~") {
            return "~~~"
        }

        return nil
    }

    static func setextHeadingLevel(in line: String) -> Int? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        guard trimmed.count >= 1 else { return nil }

        if Set(trimmed) == Set<Character>(["="]) {
            return 1
        }

        if trimmed.count >= 3, Set(trimmed) == Set<Character>(["-"]) {
            return 2
        }

        return nil
    }

    static func isIndentedCode(_ line: String) -> Bool {
        line.hasPrefix("    ") || line.hasPrefix("\t")
    }

    static func stripCodeIndent(_ line: String) -> String {
        if line.hasPrefix("\t") {
            return String(line.dropFirst())
        }

        if line.hasPrefix("    ") {
            return String(line.dropFirst(4))
        }

        return line
    }

    static func isHorizontalRule(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let compact = trimmed.filter { !$0.isWhitespace }
        guard compact.count >= 3 else { return false }

        let characters = Set(compact)
        return characters == Set<Character>(["-"]) ||
            characters == Set<Character>(["*"]) ||
            characters == Set<Character>(["_"])
    }
}
