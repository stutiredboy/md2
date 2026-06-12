import Foundation

extension String {
    /// Renderer HTML with the mode-switch source-line metadata attributes
    /// removed, so rendering-semantics assertions stay focused on the visible
    /// markup. The metadata itself is covered by `SourceLineMetadataTests`.
    var withoutSourceLineMetadata: String {
        replacingOccurrences(
            of: #" data-md2-source-(?:end-)?line="\d+""#,
            with: "",
            options: .regularExpression
        )
    }
}
