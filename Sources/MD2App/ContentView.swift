import Foundation
import MD2Core
import SwiftUI

struct ContentView: View {
    @ObservedObject var document: DocumentStore
    @ObservedObject var settings: AppSettings
    @State private var mode: EditorMode
    @State private var showsOutline: Bool
    /// Latest top-visible source line reported by the editor, used to anchor a
    /// switch into preview mode.
    @State private var editorAnchorLine = 1
    /// Latest heading id at the top of the preview viewport (and its scroll
    /// fraction fallback), used to anchor a switch into edit mode.
    @State private var previewAnchorID: String?
    @State private var previewAnchorFraction = 0.0
    /// Edit-mode find/replace bar state (write mode).
    @State private var editorFindVisible = false
    @State private var editorFindShowsReplace = false
    @State private var editorFindQuery = ""
    @State private var editorFindReplacement = ""
    @State private var editorFindFocusToken = UUID()
    @State private var editorFindNavigation: FindCommand?
    @State private var editorReplaceCommand: FindReplaceCommand?
    @State private var editorSurfaceFocusToken = UUID()
    @State private var editorMatchTotal = 0
    @State private var editorMatchIndex = 0
    /// Preview-mode find bar state (read mode).
    @State private var previewFindVisible = false
    @State private var previewFindQuery = ""
    @State private var previewFindFocusToken = UUID()
    @State private var previewFindNavigation: FindCommand?
    @State private var previewSurfaceFocusToken = UUID()
    @State private var previewMatchTotal = 0
    @State private var previewMatchIndex = 0
    private let onOpen: () -> Void

    init(document: DocumentStore, settings: AppSettings, onOpen: @escaping () -> Void) {
        self.document = document
        self.settings = settings
        self.onOpen = onOpen
        _mode = State(initialValue: settings.defaultMode)
        _showsOutline = State(initialValue: settings.showsOutlineByDefault)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if showsOutline {
                    OutlineSidebar(
                        headings: document.rendered.outline,
                        selectedHeadingID: document.jumpHeadingID,
                        settings: settings,
                        onSelect: document.jump(to:)
                    )
                    Divider()
                }

                editorSurface
            }

            Divider()
            StatusBar(stats: document.rendered.stats, url: document.fileURL, settings: settings)
        }
        .frame(minWidth: 780, minHeight: 540)
        .navigationTitle(document.displayTitle)
        .onChange(of: document.documentIdentity) { _, _ in
            applyDefaultPresentation()
            dismissEditorFind()
            dismissPreviewFind()
        }
        .onChange(of: mode) { _, _ in
            dismissEditorFind()
            dismissPreviewFind()
        }
        .onChange(of: document.findCommand) { _, command in
            handleFindCommand(command)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    showsOutline.toggle()
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help(showsOutline ? settings.text(.hideOutline) : settings.text(.showOutline))
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    onOpen()
                } label: {
                    Image(systemName: "folder")
                }
                .help(settings.text(.open))

                Button {
                    document.save()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .help(settings.text(.save))

                Picker(
                    settings.text(.mode),
                    selection: Binding(get: { mode }, set: { requestMode($0) })
                ) {
                    Image(systemName: "pencil").tag(EditorMode.write)
                    Image(systemName: "doc.richtext").tag(EditorMode.read)
                }
                .pickerStyle(.segmented)
                .frame(width: 92)
                .help(settings.text(.writeOrRead))
            }
        }
        .alert(item: $document.alert) { alert in
            Alert(
                title: Text(alert.message),
                message: Text(alert.detail),
                dismissButton: .default(Text(settings.text(.ok)))
            )
        }
    }

    private func applyDefaultPresentation() {
        mode = settings.defaultMode
        showsOutline = settings.showsOutlineByDefault
    }

    /// Dispatches a find action from the menu to the active surface.
    private func handleFindCommand(_ command: FindCommand?) {
        guard let command else { return }
        defer { document.findCommand = nil }

        switch mode {
        case .write:
            handleEditorFindAction(command.action)
        case .read:
            handlePreviewFindAction(command.action)
        }
    }

    private func handleEditorFindAction(_ action: FindCommand.Action) {
        switch action {
        case .show:
            editorFindVisible = true
            editorFindShowsReplace = false
            editorFindFocusToken = UUID()
        case .showReplace:
            editorFindVisible = true
            editorFindShowsReplace = true
            editorFindFocusToken = UUID()
        case .next, .previous:
            if editorFindVisible {
                editorFindNavigation = FindCommand(action)
            } else {
                editorFindVisible = true
                editorFindFocusToken = UUID()
            }
        }
    }

    private func dismissEditorFind(refocusEditor: Bool = false) {
        editorFindVisible = false
        editorFindQuery = ""
        editorFindNavigation = nil
        editorReplaceCommand = nil
        editorMatchTotal = 0
        editorMatchIndex = 0
        if refocusEditor {
            editorSurfaceFocusToken = UUID()
        }
    }

    private func handlePreviewFindAction(_ action: FindCommand.Action) {
        switch action {
        case .show, .showReplace:
            // Replace is unavailable in preview; both just open the find bar.
            previewFindVisible = true
            previewFindFocusToken = UUID()
        case .next, .previous:
            if previewFindVisible {
                previewFindNavigation = FindCommand(action)
            }
        }
    }

    private func dismissPreviewFind(refocusPreview: Bool = false) {
        previewFindVisible = false
        previewFindQuery = ""
        previewFindNavigation = nil
        previewMatchTotal = 0
        previewMatchIndex = 0
        if refocusPreview {
            previewSurfaceFocusToken = UUID()
        }
    }

    /// Localized "i of n" match status, "No results", or empty when idle.
    private var previewStatusText: String {
        matchStatusText(query: previewFindQuery, total: previewMatchTotal, index: previewMatchIndex)
    }

    private var editorStatusText: String {
        matchStatusText(query: editorFindQuery, total: editorMatchTotal, index: editorMatchIndex)
    }

    private func matchStatusText(query: String, total: Int, index: Int) -> String {
        if query.isEmpty { return "" }
        if total == 0 { return settings.text(.noResults) }
        return String(format: settings.text(.matchStatus), index, total)
    }

    /// Switches mode, first resolving the outgoing view's anchor to a target on
    /// the incoming view. The anchor is set on `document` *before* `mode` flips,
    /// so the freshly-created destination view already knows where to land when
    /// it loads — critical for the preview, whose page load can be slow when
    /// heavy diagram/math engines are inlined.
    private func requestMode(_ newMode: EditorMode) {
        guard newMode != mode else { return }
        let outline = document.rendered.outline

        switch newMode {
        case .read:
            // Write → Read: anchor the preview on the section the editor was in.
            let heading = outline.heading(atOrAbove: editorAnchorLine)
            if let heading {
                document.jumpFraction = nil
                document.jumpHeadingID = heading.id
            } else {
                document.jumpHeadingID = nil
                document.jumpFraction = fraction(
                    forLine: editorAnchorLine,
                    totalLines: totalLineCount
                )
            }
        case .write:
            // Read → Write: anchor the editor on the section the preview showed.
            let heading = previewAnchorID.flatMap(outline.heading(forID:))
            if let heading {
                document.jumpFraction = nil
                document.jumpLine = heading.line
            } else {
                document.jumpLine = nil
                document.jumpFraction = previewAnchorFraction
            }
        }

        mode = newMode
    }

    private var totalLineCount: Int {
        document.text.reduce(into: 1) { count, character in
            if character == "\n" { count += 1 }
        }
    }

    @ViewBuilder
    private var editorSurface: some View {
        switch mode {
        case .write:
            ZStack(alignment: .top) {
                MarkdownEditorView(
                    text: $document.text,
                    jumpLine: $document.jumpLine,
                    jumpFraction: $document.jumpFraction,
                    onAnchorLineChange: { editorAnchorLine = $0 },
                    onEnterPreview: { requestMode(.read) },
                    findQuery: $editorFindQuery,
                    findNavigation: $editorFindNavigation,
                    findReplacement: $editorFindReplacement,
                    replaceCommand: $editorReplaceCommand,
                    focusToken: editorSurfaceFocusToken,
                    onFindShortcut: handleEditorFindAction(_:),
                    onFindResult: { total, index in
                        editorMatchTotal = total
                        editorMatchIndex = index
                    }
                )

                if editorFindVisible {
                    EditorFindBar(
                        query: $editorFindQuery,
                        replacement: $editorFindReplacement,
                        showsReplace: editorFindShowsReplace,
                        focusToken: editorFindFocusToken,
                        statusText: editorStatusText,
                        settings: settings,
                        onNext: { editorFindNavigation = FindCommand(.next) },
                        onPrevious: { editorFindNavigation = FindCommand(.previous) },
                        onReplace: { editorReplaceCommand = FindReplaceCommand(.current) },
                        onReplaceAll: { editorReplaceCommand = FindReplaceCommand(.all) },
                        onClose: { dismissEditorFind(refocusEditor: true) }
                    )
                }
            }
        case .read:
            ZStack(alignment: .top) {
                MarkdownPreviewView(
                    html: document.rendered.html,
                    baseURL: document.baseURL,
                    jumpHeadingID: $document.jumpHeadingID,
                    jumpFraction: $document.jumpFraction,
                    onAnchorChange: { id, fraction in
                        previewAnchorID = id
                        previewAnchorFraction = fraction
                    },
                    onEnterEdit: { requestMode(.write) },
                    findQuery: $previewFindQuery,
                    findNavigation: $previewFindNavigation,
                    focusToken: previewSurfaceFocusToken,
                    onFindShortcut: handlePreviewFindAction(_:),
                    onFindResult: { total, index in
                        previewMatchTotal = total
                        previewMatchIndex = index
                    }
                )

                if previewFindVisible {
                    PreviewFindBar(
                        query: $previewFindQuery,
                        focusToken: previewFindFocusToken,
                        statusText: previewStatusText,
                        settings: settings,
                        onNext: { previewFindNavigation = FindCommand(.next) },
                        onPrevious: { previewFindNavigation = FindCommand(.previous) },
                        onClose: { dismissPreviewFind(refocusPreview: true) }
                    )
                }
            }
        }
    }
}

private struct OutlineSidebar: View {
    let headings: [Heading]
    let selectedHeadingID: String?
    let settings: AppSettings
    let onSelect: (Heading) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(settings.text(.outline))
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 8)

            if headings.isEmpty {
                Text(settings.text(.noHeadings))
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .padding(14)
                Spacer()
            } else {
                List(headings) { heading in
                    Button {
                        onSelect(heading)
                    } label: {
                        HStack(spacing: 0) {
                            Color.clear
                                .frame(width: CGFloat(max(0, heading.level - 1)) * 12)
                            Text(heading.title)
                                .lineLimit(1)
                                .font(heading.level == 1 ? .callout.weight(.semibold) : .callout)
                        }
                        .foregroundStyle(selectedHeadingID == heading.id ? .primary : .secondary)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.sidebar)
            }
        }
        .frame(width: 230)
        .background(.regularMaterial)
    }
}

private struct StatusBar: View {
    let stats: DocumentStats
    let url: URL?
    let settings: AppSettings

    var body: some View {
        HStack(spacing: 14) {
            Text("\(stats.words) \(settings.text(.words))")
            Text("\(stats.characters) \(settings.text(.chars))")
            Text("\(stats.lines) \(settings.text(.lines))")
            Text("\(stats.readingMinutes) \(settings.text(.minRead))")

            Spacer()

            if let url {
                Text(url.path)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .frame(height: 28)
        .background(.bar)
    }
}
