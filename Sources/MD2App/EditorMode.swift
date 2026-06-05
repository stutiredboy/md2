import Foundation

enum EditorMode: String, CaseIterable, Identifiable {
    case write
    case read

    var id: String {
        rawValue
    }
}
