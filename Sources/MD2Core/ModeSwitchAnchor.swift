import Foundation

/// A cross-mode scroll target, captured from the view the user is leaving and
/// applied to the view they are entering when toggling Write↔Read.
///
/// - ``heading(id:)`` targets the preview by HTML element id.
/// - ``fraction(_:)`` targets either view proportionally (0...1) when no
///   section heading is available to anchor on.
///
/// The editor is targeted directly by 1-based source line through a separate
/// `jumpLine` binding rather than through this enum.
public enum ModeSwitchAnchor: Equatable, Sendable {
    case heading(id: String)
    case fraction(Double)
}

public extension Array where Element == Heading {
    /// The last heading at or above `line` — i.e. the section the given source
    /// line belongs to. Returns `nil` when `line` precedes the first heading or
    /// the outline is empty.
    func heading(atOrAbove line: Int) -> Heading? {
        var match: Heading?
        for heading in self {
            if heading.line <= line {
                match = heading
            } else {
                break
            }
        }
        return match
    }

    /// The heading carrying the given element id, if any.
    func heading(forID id: String) -> Heading? {
        first { $0.id == id }
    }
}

/// Maps a 1-based source line to a 0...1 fraction of a document of
/// `totalLines` lines. Used for the no-heading proportional fallback.
public func fraction(forLine line: Int, totalLines: Int) -> Double {
    guard totalLines > 1 else { return 0 }
    let clamped = min(max(line, 1), totalLines)
    return Double(clamped - 1) / Double(totalLines - 1)
}
