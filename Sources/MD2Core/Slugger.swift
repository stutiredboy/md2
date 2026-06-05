import Foundation

enum Slugger {
    static func uniqueSlug(for title: String, usedSlugs: inout [String: Int]) -> String {
        let base = slug(for: title)
        let count = usedSlugs[base, default: 0] + 1
        usedSlugs[base] = count

        return count == 1 ? base : "\(base)-\(count)"
    }

    private static func slug(for title: String) -> String {
        let folded = title
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        var result = ""
        var lastWasSeparator = false

        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                result.unicodeScalars.append(scalar)
                lastWasSeparator = false
            } else if !lastWasSeparator {
                result.append("-")
                lastWasSeparator = true
            }
        }

        let trimmed = result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "section" : trimmed
    }
}
