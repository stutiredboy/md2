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
            }
        }
    }

    @Published private(set) var rendered: RenderedDocument
    @Published private(set) var fileURL: URL?
    @Published private(set) var isDirty = false
    @Published var alert: DocumentAlert?
    @Published var jumpLine: Int?
    @Published var jumpHeadingID: String?
    @Published private(set) var documentIdentity = UUID()

    private let renderer = MarkdownRenderer()
    private var isLoading = false
    private var didLoadInitialFile = false

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

    func newDocument() {
        setDocumentText(Self.starterMarkdown, fileURL: nil, dirty: false)
    }

    func openDocument() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = Self.markdownTypes

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        open(url)
    }

    func save() {
        if let fileURL {
            write(to: fileURL)
        } else {
            saveAs()
        }
    }

    func saveAs() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = Self.markdownTypes
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = fileURL?.lastPathComponent ?? "Untitled.md"

        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }

        write(to: url)
    }

    func loadInitialFileFromArguments() {
        guard !didLoadInitialFile else { return }
        didLoadInitialFile = true

        let arguments = CommandLine.arguments.dropFirst()
        guard let path = arguments.first(where: { !$0.hasPrefix("-") }) else {
            return
        }

        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        open(url)
    }

    func jump(to heading: Heading) {
        jumpLine = heading.line
        jumpHeadingID = heading.id
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

    private func write(to url: URL) {
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            fileURL = url
            isDirty = false
        } catch {
            alert = DocumentAlert(message: "Could not save \(url.lastPathComponent).", detail: error.localizedDescription)
        }
    }

    private func setDocumentText(_ newText: String, fileURL newFileURL: URL?, dirty: Bool) {
        isLoading = true
        text = newText
        fileURL = newFileURL
        isDirty = dirty
        rendered = renderer.render(newText)
        documentIdentity = UUID()
        isLoading = false
    }

    private static var markdownTypes: [UTType] {
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
