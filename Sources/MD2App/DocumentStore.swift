import AppKit
import Foundation
import MD2Core
import UniformTypeIdentifiers

@MainActor
final class DocumentStore: ObservableObject {
    @Published var text: String {
        didSet {
            guard text != oldValue else { return }
            rendered = renderer.render(text)
            if !isLoading {
                isDirty = true
                scheduleAutosaveIfNeeded()
            }
        }
    }

    @Published private(set) var rendered: RenderedDocument
    @Published private(set) var fileURL: URL?
    @Published private(set) var isDirty = false
    @Published var alert: DocumentAlert?
    @Published var jumpLine: Int?
    @Published var jumpHeadingID: String?
    @Published var jumpFraction: Double?
    /// Mode-switch viewport anchors, one per destination surface so the
    /// outgoing view can never consume the incoming view's target during the
    /// transition. They take precedence over the single-target jump bindings
    /// above and are consumed once applied.
    @Published var editorJumpAnchor: ViewportAnchor?
    @Published var previewJumpAnchor: ViewportAnchor?
    @Published private(set) var documentIdentity = UUID()
    /// Set by Find menu commands; observed by `ContentView`, which dispatches the
    /// action to whichever surface (editor or preview) is currently active.
    @Published var findCommand: FindCommand?

    private let renderer = MarkdownRenderer()
    private var isLoading = false
    private var autosaveWorkItem: DispatchWorkItem?
    private let autosaveDelay: TimeInterval = 5

    var baseURL: URL? {
        fileURL?.deletingLastPathComponent()
    }

    var displayTitle: String {
        let name = fileURL?.lastPathComponent ?? "Untitled.md"
        return isDirty ? "\(name) *" : name
    }

    init() {
        let starterText = Self.starterMarkdown
        text = starterText
        rendered = renderer.render(starterText)
    }

    /// True when this store still holds the untouched starter document, i.e. it
    /// has never been saved to disk and has no unsaved edits. Such a window can
    /// be reused to load a freshly opened file instead of spawning a new one.
    var isReusableEmptyDocument: Bool {
        fileURL == nil && !isDirty && text == Self.starterMarkdown
    }

    @discardableResult
    func save() -> Bool {
        if let fileURL {
            return write(to: fileURL)
        } else {
            return saveAs()
        }
    }

    @discardableResult
    func saveAs() -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = Self.markdownTypes
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = fileURL?.lastPathComponent ?? "Untitled.md"

        guard panel.runModal() == .OK, let url = panel.url else {
            return false
        }

        return write(to: url)
    }

    /// Relays a find action from a menu command to the active document surface.
    func requestFind(_ action: FindCommand.Action) {
        findCommand = FindCommand(action)
    }

    func jump(to heading: Heading) {
        editorJumpAnchor = nil
        previewJumpAnchor = nil
        jumpFraction = nil
        jumpLine = heading.line
        jumpHeadingID = heading.id
    }

    /// Sets the task-list marker on the 1-based source `line` to `checked`,
    /// in response to a checkbox click in the preview. The request is
    /// validated before anything is written — the line must exist and must
    /// be a task item — so a stale or malformed preview message can never
    /// corrupt unrelated text. Applying an absolute state (instead of
    /// flipping) keeps duplicate messages idempotent; re-render, dirty
    /// marking, and autosave ride the normal `text` pipeline. Returns
    /// whether the line was a valid task item (so a caller can skip
    /// reload-related work for ignored requests).
    @discardableResult
    func toggleTask(atLine line: Int, to checked: Bool) -> Bool {
        guard let lineRange = Self.rangeOfLine(line, in: text),
              let updated = Self.settingTaskMarker(in: String(text[lineRange]), to: checked) else {
            return false
        }
        text = text.replacingCharacters(in: lineRange, with: updated)
        return true
    }

    /// Character range of the 1-based `line` (excluding its terminator),
    /// counting `\n`, `\r\n`, and `\r` as terminators — the same numbering
    /// `normalizedMarkdownLines` gives the renderer's source-line metadata.
    private static func rangeOfLine(_ line: Int, in text: String) -> Range<String.Index>? {
        guard line >= 1 else { return nil }

        var lineNumber = 1
        var lineStart = text.startIndex
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            // "\r\n" is a single Character in Swift, so each terminator is
            // one grapheme regardless of style.
            if character == "\n" || character == "\r" || character == "\r\n" {
                if lineNumber == line {
                    return lineStart..<index
                }
                lineNumber += 1
                index = text.index(after: index)
                lineStart = index
            } else {
                index = text.index(after: index)
            }
        }

        return lineNumber == line ? lineStart..<text.endIndex : nil
    }

    /// Rewrites the task marker of a single source line to `checked`,
    /// returning `nil` when the line is not a task-list item. Mirrors the
    /// renderer's task syntax: optional leading whitespace and blockquote
    /// `>` prefixes, a `-`/`*`/`+` bullet, one space, then `[ ]`, `[x]`, or
    /// `[X]` followed by a space. Only the mark character changes.
    private static func settingTaskMarker(in line: String, to checked: Bool) -> String? {
        var index = line.startIndex

        // Skip indentation and blockquote prefixes (e.g. "  > > - [ ] x").
        while index < line.endIndex, line[index] == " " || line[index] == "\t" || line[index] == ">" {
            index = line.index(after: index)
        }

        guard index < line.endIndex, "-*+".contains(line[index]) else { return nil }
        index = line.index(after: index)
        guard index < line.endIndex, line[index] == " " else { return nil }
        index = line.index(after: index)

        guard index < line.endIndex, line[index] == "[" else { return nil }
        let markIndex = line.index(after: index)
        guard markIndex < line.endIndex, " xX".contains(line[markIndex]) else { return nil }
        let closeIndex = line.index(after: markIndex)
        guard closeIndex < line.endIndex, line[closeIndex] == "]" else { return nil }
        let spaceIndex = line.index(after: closeIndex)
        guard spaceIndex < line.endIndex, line[spaceIndex] == " " else { return nil }

        var updated = line
        updated.replaceSubrange(markIndex...markIndex, with: checked ? "x" : " ")
        return updated
    }

    func open(_ url: URL) {
        load(from: url)
    }

    private func load(from url: URL) {
        do {
            let loadedText = try String(contentsOf: url, encoding: .utf8)
            setDocumentText(loadedText, fileURL: url, dirty: false)
        } catch {
            alert = DocumentAlert(message: "Could not open \(url.lastPathComponent).", detail: error.localizedDescription)
        }
    }

    @discardableResult
    private func write(to url: URL) -> Bool {
        do {
            autosaveWorkItem?.cancel()
            autosaveWorkItem = nil
            try text.write(to: url, atomically: true, encoding: .utf8)
            fileURL = url
            isDirty = false
            return true
        } catch {
            alert = DocumentAlert(message: "Could not save \(url.lastPathComponent).", detail: error.localizedDescription)
            return false
        }
    }

    private func setDocumentText(_ newText: String, fileURL newFileURL: URL?, dirty: Bool) {
        autosaveWorkItem?.cancel()
        autosaveWorkItem = nil
        isLoading = true
        text = newText
        fileURL = newFileURL
        isDirty = dirty
        rendered = renderer.render(newText)
        documentIdentity = UUID()
        isLoading = false
    }

    private func scheduleAutosaveIfNeeded() {
        guard fileURL != nil else {
            autosaveWorkItem?.cancel()
            autosaveWorkItem = nil
            return
        }

        autosaveWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.autosaveNow()
            }
        }
        autosaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + autosaveDelay, execute: workItem)
    }

    private func autosaveNow() {
        guard let fileURL, isDirty else {
            return
        }

        _ = write(to: fileURL)
    }

    static var markdownTypes: [UTType] {
        [
            UTType(filenameExtension: "md"),
            UTType(filenameExtension: "markdown"),
            .plainText
        ].compactMap { $0 }
    }

    private static let starterMarkdown = """
    # Untitled

    Start writing in Markdown.

    - [ ] Draft
    - [ ] Review
    - [ ] Ship
    """
}

struct DocumentAlert: Identifiable {
    let id = UUID()
    let message: String
    let detail: String
}
