import Foundation

public struct Heading: Identifiable, Equatable, Sendable {
    public let id: String
    public let level: Int
    public let title: String
    public let line: Int

    public init(id: String, level: Int, title: String, line: Int) {
        self.id = id
        self.level = level
        self.title = title
        self.line = line
    }
}
