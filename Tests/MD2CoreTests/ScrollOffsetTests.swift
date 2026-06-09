import Testing
@testable import MD2Core

struct ScrollOffsetTests {
    // MARK: - Content fits the viewport

    @Test func contentShorterThanViewportYieldsZero() {
        #expect(clampedScrollOffset(targetY: 200, contentHeight: 400, viewportHeight: 800) == 0)
    }

    @Test func contentEqualToViewportYieldsZero() {
        #expect(clampedScrollOffset(targetY: 200, contentHeight: 800, viewportHeight: 800) == 0)
    }

    // MARK: - Content taller than the viewport

    @Test func midRangeTargetIsUnchanged() {
        #expect(clampedScrollOffset(targetY: 300, contentHeight: 2000, viewportHeight: 800) == 300)
    }

    @Test func targetAboveTopClampsToZero() {
        #expect(clampedScrollOffset(targetY: -50, contentHeight: 2000, viewportHeight: 800) == 0)
    }

    @Test func targetBelowRangeClampsToMaxOffset() {
        // maxOffset = 2000 - 800 = 1200
        #expect(clampedScrollOffset(targetY: 5000, contentHeight: 2000, viewportHeight: 800) == 1200)
    }

    @Test func targetExactlyAtMaxOffsetIsUnchanged() {
        #expect(clampedScrollOffset(targetY: 1200, contentHeight: 2000, viewportHeight: 800) == 1200)
    }

    // MARK: - Degenerate inputs

    @Test func zeroHeightsYieldZero() {
        #expect(clampedScrollOffset(targetY: 100, contentHeight: 0, viewportHeight: 0) == 0)
    }

    @Test func negativeContentHeightYieldsZero() {
        #expect(clampedScrollOffset(targetY: 100, contentHeight: -10, viewportHeight: 800) == 0)
    }
}
