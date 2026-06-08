import Foundation

/// Case- and diacritic-insensitive substring search backing the editor's
/// find/replace. Pure Foundation logic, kept in MD2Core so it is unit-testable
/// independently of the AppKit text view that drives it.
public enum TextSearch {
    /// Every non-overlapping match range of `query` in `text`, left to right.
    /// Returns an empty array for an empty query. Matching is case- and
    /// diacritic-insensitive. A zero-length match advances by one to guarantee
    /// progress.
    public static func matches(of query: String, in text: String) -> [NSRange] {
        guard !query.isEmpty else { return [] }
        let source = text as NSString
        var results: [NSRange] = []
        var searchRange = NSRange(location: 0, length: source.length)

        while searchRange.length > 0 {
            let range = source.range(
                of: query,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: searchRange
            )
            if range.location == NSNotFound {
                break
            }
            results.append(range)

            let nextLocation = range.location + max(range.length, 1)
            let remaining = source.length - nextLocation
            searchRange = NSRange(location: nextLocation, length: max(0, remaining))
        }

        return results
    }
}
