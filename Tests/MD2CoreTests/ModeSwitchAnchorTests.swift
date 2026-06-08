import Testing
@testable import MD2Core

struct ModeSwitchAnchorTests {
    private let outline = [
        Heading(id: "intro", level: 1, title: "Intro", line: 1),
        Heading(id: "setup", level: 2, title: "Setup", line: 10),
        Heading(id: "usage", level: 2, title: "Usage", line: 25)
    ]

    // MARK: - heading(atOrAbove:)

    @Test func headingAtOrAboveReturnsSectionForLineBetweenHeadings() {
        #expect(outline.heading(atOrAbove: 15)?.id == "setup")
    }

    @Test func headingAtOrAboveReturnsHeadingWhenLineIsExactlyOnIt() {
        #expect(outline.heading(atOrAbove: 25)?.id == "usage")
        #expect(outline.heading(atOrAbove: 1)?.id == "intro")
    }

    @Test func headingAtOrAboveReturnsLastSectionForLineBelowAll() {
        #expect(outline.heading(atOrAbove: 999)?.id == "usage")
    }

    @Test func headingAtOrAboveReturnsNilBeforeFirstHeading() {
        let shifted = [Heading(id: "later", level: 1, title: "Later", line: 5)]
        #expect(shifted.heading(atOrAbove: 1) == nil)
    }

    @Test func headingAtOrAboveReturnsNilForEmptyOutline() {
        #expect([Heading]().heading(atOrAbove: 10) == nil)
    }

    // MARK: - heading(forID:)

    @Test func headingForIDResolvesKnownID() {
        #expect(outline.heading(forID: "usage")?.line == 25)
    }

    @Test func headingForIDReturnsNilForUnknownID() {
        #expect(outline.heading(forID: "missing") == nil)
    }

    // MARK: - fraction(forLine:)

    @Test func fractionForLineMapsEndpoints() {
        #expect(fraction(forLine: 1, totalLines: 101) == 0)
        #expect(fraction(forLine: 101, totalLines: 101) == 1)
        #expect(fraction(forLine: 51, totalLines: 101) == 0.5)
    }

    @Test func fractionForLineClampsOutOfRange() {
        #expect(fraction(forLine: 0, totalLines: 101) == 0)
        #expect(fraction(forLine: 500, totalLines: 101) == 1)
    }

    @Test func fractionForLineHandlesDegenerateDocuments() {
        #expect(fraction(forLine: 1, totalLines: 1) == 0)
        #expect(fraction(forLine: 5, totalLines: 0) == 0)
    }
}
