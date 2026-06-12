import Foundation

extension String {
    /// Renderer HTML with the source-line metadata attributes (mode-switch
    /// block spans and task-checkbox lines) removed, so rendering-semantics
    /// assertions stay focused on the visible markup. The metadata itself is
    /// covered by `SourceLineMetadataTests`.
    var withoutSourceLineMetadata: String {
        replacingOccurrences(
            of: #" data-md2-(?:source-(?:end-)?line|task-line)="\d+""#,
            with: "",
            options: .regularExpression
        )
    }
}
