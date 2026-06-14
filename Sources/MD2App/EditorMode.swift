import Foundation

enum EditorMode: String, CaseIterable, Identifiable {
    case write
    /// Side by Side: editor on the left, live preview on the right.
    case split
    case read

    var id: String {
        rawValue
    }
}
