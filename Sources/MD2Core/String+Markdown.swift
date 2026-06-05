import Foundation

extension String {
    var normalizedMarkdownLines: [String] {
        replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
    }

    var trimmedMarkdownLine: String {
        trimmingCharacters(in: .whitespaces)
    }
}
