import Foundation

public struct DocumentStats: Equatable, Sendable {
    public let words: Int
    public let characters: Int
    public let lines: Int
    public let readingMinutes: Int

    public init(markdown: String) {
        characters = markdown.count
        lines = markdown.isEmpty ? 0 : markdown.split(
            separator: "\n",
            omittingEmptySubsequences: false
        ).count

        var wordCount = 0
        markdown.enumerateSubstrings(
            in: markdown.startIndex..<markdown.endIndex,
            options: [.byWords, .localized]
        ) { _, _, _, _ in
            wordCount += 1
        }

        words = wordCount
        readingMinutes = wordCount == 0 ? 0 : max(1, Int(ceil(Double(wordCount) / 240.0)))
    }
}
