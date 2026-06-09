import Foundation

/// Clamps a desired vertical scroll offset to the range a view can actually
/// scroll, given its content and viewport heights.
///
/// Returns `0` whenever the content fits within the viewport
/// (`contentHeight <= viewportHeight`), i.e. there is no scrollable range — a
/// document that fits on screen must stay pinned to the top and is never
/// scrolled out of view. Otherwise the offset is clamped to
/// `0...(contentHeight - viewportHeight)` so it can neither go above the top
/// nor past the last scrollable position.
///
/// This mirrors the pure, unit-tested anchor helpers in ``ModeSwitchAnchor`` so
/// the "short document stays at the top" rule is provable without driving
/// AppKit. Heights are taken as `Double` to keep this core helper free of any
/// CoreGraphics/AppKit dependency; callers convert from `CGFloat`.
public func clampedScrollOffset(
    targetY: Double,
    contentHeight: Double,
    viewportHeight: Double
) -> Double {
    let maxOffset = contentHeight - viewportHeight
    guard maxOffset > 0 else { return 0 }
    return min(max(targetY, 0), maxOffset)
}
