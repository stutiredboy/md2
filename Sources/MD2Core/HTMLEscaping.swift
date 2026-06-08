import Foundation

/// Centralized HTML escaping shared by the renderer and the syntax highlighter
/// so the escaping rules live in exactly one place and cannot drift apart.
enum HTMLEscaping {
    /// Escapes the five characters that are unsafe in element text / double-quoted
    /// attribute context.
    static func escape(_ source: String) -> String {
        source
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// Attribute-context escaping additionally encodes the single quote, for use
    /// in single-quoted attribute values.
    static func escapeAttribute(_ source: String) -> String {
        escape(source).replacingOccurrences(of: "'", with: "&#39;")
    }
}
