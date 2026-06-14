import Foundation

/// Single source of truth for the CSS class names that couple three otherwise
/// independent places: the renderer's generated HTML, the `diagramScripts`
/// engine-detection in Swift, and the inlined preview JavaScript bootstraps.
/// Centralizing them means a rename is one edit (compiler-checked on the Swift
/// side) instead of silently diverging across the copies.
///
/// Scope: only the diagram/math families carry this generator ↔ detector ↔ JS
/// coupling. Pure-stylesheet classes consumed solely by the inlined CSS (`toc`,
/// `task-list`, `footnote-ref`, `image-frame`, …) are intentionally left as
/// literals — they have no Swift detection or JS dependency to drift against.
public enum PreviewClass {
    public static let diagram = "diagram"
    public static let diagramMermaid = "diagram-mermaid"
    public static let diagramFlow = "diagram-flow"
    public static let diagramSequence = "diagram-sequence"
    public static let diagramPending = "diagram-pending"
    public static let diagramReady = "diagram-ready"
    public static let diagramError = "diagram-error"

    public static let math = "math"
    public static let mathDisplay = "math-display"
    public static let mathInline = "math-inline"
    public static let mathError = "math-error"
}
