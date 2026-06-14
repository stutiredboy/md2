import Foundation

public struct RenderedDocument: Equatable, Sendable {
    public let html: String
    /// The rendered content that sits inside the page's `<main>` element,
    /// without the surrounding document shell (head/scripts). Used by the
    /// live-preview path to swap content in place without reloading the page.
    public let body: String
    public let outline: [Heading]
    public let stats: DocumentStats

    public init(html: String, body: String, outline: [Heading], stats: DocumentStats) {
        self.html = html
        self.body = body
        self.outline = outline
        self.stats = stats
    }
}
