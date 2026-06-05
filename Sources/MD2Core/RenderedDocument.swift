import Foundation

public struct RenderedDocument: Equatable, Sendable {
    public let html: String
    public let outline: [Heading]
    public let stats: DocumentStats

    public init(html: String, outline: [Heading], stats: DocumentStats) {
        self.html = html
        self.outline = outline
        self.stats = stats
    }
}
