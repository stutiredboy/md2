import Foundation

/// A find action relayed from a menu command to whichever document surface is
/// currently active. Each instance carries a fresh `token` so that repeating the
/// same action (e.g. pressing ⌘G twice) still registers as a change for
/// SwiftUI's `onChange` observation.
struct FindCommand: Equatable {
    enum Action {
        case show
        case showReplace
        case next
        case previous
    }

    let action: Action
    let token = UUID()

    init(_ action: Action) {
        self.action = action
    }
}

struct FindReplaceCommand: Equatable {
    enum Action {
        case current
        case all
    }

    let action: Action
    let token = UUID()

    init(_ action: Action) {
        self.action = action
    }
}
