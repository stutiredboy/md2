import Testing
@testable import MD2Core

struct ViewportAnchorTests {
    // MARK: - clampedUnitProgress

    @Test func unitProgressClampsToZeroOne() {
        #expect(clampedUnitProgress(-0.5) == 0)
        #expect(clampedUnitProgress(0) == 0)
        #expect(clampedUnitProgress(0.42) == 0.42)
        #expect(clampedUnitProgress(1) == 1)
        #expect(clampedUnitProgress(7.3) == 1)
    }

    @Test func unitProgressMapsNonFiniteToZero() {
        #expect(clampedUnitProgress(.nan) == 0)
        #expect(clampedUnitProgress(.infinity) == 0)
        #expect(clampedUnitProgress(-.infinity) == 0)
    }

    // MARK: - resolvedSourceLine

    @Test func resolvedLineInterpolatesAcrossSpan() {
        #expect(resolvedSourceLine(start: 100, end: 180, progress: 0) == 100)
        #expect(resolvedSourceLine(start: 100, end: 180, progress: 0.25) == 120)
        #expect(resolvedSourceLine(start: 100, end: 180, progress: 0.5) == 140)
        #expect(resolvedSourceLine(start: 100, end: 180, progress: 1) == 180)
    }

    @Test func resolvedLineClampsProgressInsideSpan() {
        #expect(resolvedSourceLine(start: 10, end: 20, progress: -3) == 10)
        #expect(resolvedSourceLine(start: 10, end: 20, progress: 42) == 20)
        #expect(resolvedSourceLine(start: 10, end: 20, progress: .nan) == 10)
    }

    @Test func resolvedLineCollapsesMissingOrMalformedSpan() {
        #expect(resolvedSourceLine(start: 7, end: nil, progress: 0.9) == 7)
        #expect(resolvedSourceLine(start: 7, end: 7, progress: 0.9) == 7)
        #expect(resolvedSourceLine(start: 7, end: 3, progress: 0.9) == 7)
    }

    @Test func resolvedLineNormalizesNonPositiveStart() {
        #expect(resolvedSourceLine(start: 0, end: nil, progress: 0) == 1)
        #expect(resolvedSourceLine(start: -5, end: 4, progress: 1) == 4)
    }

    // MARK: - ViewportAnchor

    @Test func targetSourceLineAdvancesByProgress() {
        let anchor = ViewportAnchor(
            sourceLine: 50,
            sourceEndLine: 60,
            intraBlockProgress: 0.5
        )
        #expect(anchor.targetSourceLine == 55)
    }

    @Test func targetSourceLineIsNilWithoutSourceLine() {
        let anchor = ViewportAnchor(scrollFraction: 0.7, fallbackHeadingID: "intro")
        #expect(anchor.targetSourceLine == nil)
    }

    @Test func initSanitizesProgressInsetAndFraction() {
        let anchor = ViewportAnchor(
            sourceLine: 3,
            intraBlockProgress: 9,
            viewportTopInset: -12,
            scrollFraction: .nan
        )
        #expect(anchor.intraBlockProgress == 1)
        #expect(anchor.viewportTopInset == 0)
        #expect(anchor.scrollFraction == 0)
    }
}
