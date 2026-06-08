import Foundation
import Testing
@testable import MD2Core

struct TextSearchTests {
    @Test func emptyQueryHasNoMatches() {
        #expect(TextSearch.matches(of: "", in: "anything").isEmpty)
    }

    @Test func noMatchReturnsEmpty() {
        #expect(TextSearch.matches(of: "zzz", in: "hello world").isEmpty)
    }

    @Test func findsSingleMatch() {
        let matches = TextSearch.matches(of: "world", in: "hello world")
        #expect(matches == [NSRange(location: 6, length: 5)])
    }

    @Test func findsMultipleNonOverlappingMatches() {
        let matches = TextSearch.matches(of: "aa", in: "aaaa")
        #expect(matches.map(\.location) == [0, 2])
    }

    @Test func matchingIsCaseInsensitive() {
        let matches = TextSearch.matches(of: "ABC", in: "abc ABC AbC")
        #expect(matches.count == 3)
    }

    @Test func matchingIsDiacriticInsensitive() {
        let matches = TextSearch.matches(of: "cafe", in: "a café here")
        #expect(matches.count == 1)
    }

    @Test func singleCharacterMatchesAdvanceByOne() {
        let matches = TextSearch.matches(of: "a", in: "aaa")
        #expect(matches.map(\.location) == [0, 1, 2])
    }
}
