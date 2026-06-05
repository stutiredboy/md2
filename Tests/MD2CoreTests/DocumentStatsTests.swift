import Testing
@testable import MD2Core

struct DocumentStatsTests {
    @Test func countsBasicDocumentStats() {
        let stats = DocumentStats(markdown: "Hello world\nThis is MD2")

        #expect(stats.words == 5)
        #expect(stats.characters == 23)
        #expect(stats.lines == 2)
        #expect(stats.readingMinutes == 1)
    }

    @Test func emptyDocumentHasNoReadingTime() {
        let stats = DocumentStats(markdown: "")

        #expect(stats.words == 0)
        #expect(stats.characters == 0)
        #expect(stats.lines == 0)
        #expect(stats.readingMinutes == 0)
    }
}
