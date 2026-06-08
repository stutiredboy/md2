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
enum PreviewClass {
    static let diagram = "diagram"
    static let diagramMermaid = "diagram-mermaid"
    static let diagramFlow = "diagram-flow"
    static let diagramSequence = "diagram-sequence"
    static let diagramPending = "diagram-pending"
    static let diagramReady = "diagram-ready"
    static let diagramError = "diagram-error"

    static let math = "math"
    static let mathDisplay = "math-display"
    static let mathInline = "math-inline"
    static let mathError = "math-error"
}
