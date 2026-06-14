import Foundation
import MD2Core
import SwiftUI

struct ContentView: View {
    @ObservedObject var document: DocumentStore
    @ObservedObject var settings: AppSettings
    @State private var mode: EditorMode
    @State private var showsOutline: Bool
    /// Latest top-visible source line reported by the editor — the cached
    /// fallback when a live capture is unavailable at switch time.
    @State private var editorAnchorLine = 1
    /// Latest debounced viewport anchor reported by the preview — the cached
    /// fallback when the live capture does not answer in time.
    @State private var previewAnchor: ViewportAnchor?
    /// On-demand readers for the *live* outgoing surface, so a switch right
    /// after a scroll uses the current viewport rather than a stale callback.
    @State private var editorViewport = EditorViewportReader()
    @State private var previewViewport = PreviewViewportReader()
    /// True while a Read→Write switch waits for the preview's async anchor
    /// capture, so repeated requests cannot race each other.
    @State private var isCapturingPreviewAnchor = false
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
    /// Side by Side: the pane that most recently had user interaction, so a
    /// menu-driven Find routes to the surface the user is actually working in.
    @State private var focusedPane: SplitPane = .editor
    /// Side by Side scroll-sync driver: the pane currently driving the other.
    /// While set, the follower's settle-time anchor reports are ignored so the
    /// two panes cannot oscillate against each other.
    @State private var splitSyncSource: SplitPane?
    /// Re-armed every time a pane drives the sync; the matching delayed reset is
    /// the only one that clears `splitSyncSource`.
    @State private var splitSyncToken = UUID()
    /// Coalesces the editor's per-tick scroll reports into one preview drive, so
    /// fast scrolling does not flood the preview with scroll commands.
    @State private var editorSyncWork: DispatchWorkItem?
    /// Per-pane minimum width in Side by Side so neither side collapses.
    private let splitPaneMinWidth: CGFloat = 340
    private let onOpen: () -> Void

    init(document: DocumentStore, settings: AppSettings, onOpen: @escaping () -> Void) {
        self.document = document
        self.settings = settings
        self.onOpen = onOpen
        _mode = State(initialValue: settings.presentationMode(isFileBacked: document.fileURL != nil))
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
        .frame(minWidth: mode == .split ? 1000 : 780, minHeight: 540)
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
                    Image(systemName: "rectangle.split.2x1").tag(EditorMode.split)
                    Image(systemName: "doc.richtext").tag(EditorMode.read)
                }
                .pickerStyle(.segmented)
                .frame(width: 132)
                .help(settings.text(.writeReadOrSplit))
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
        mode = settings.presentationMode(isFileBacked: document.fileURL != nil)
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
        case .split:
            // Route a menu-driven Find to the pane the user last worked in.
            if focusedPane == .preview {
                handlePreviewFindAction(command.action)
            } else {
                handleEditorFindAction(command.action)
            }
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

    /// Switches mode, first resolving the outgoing view's viewport anchor to a
    /// target on the incoming view. The anchor is captured fresh from the live
    /// outgoing surface at request time (the cached scroll callback is only the
    /// fallback), and is set on `document` *before* `mode` flips, so the
    /// freshly-created destination view already knows where to land when it
    /// loads — critical for the preview, whose page load can be slow when
    /// heavy diagram/math engines are inlined.
    private func requestMode(_ newMode: EditorMode) {
        guard newMode != mode else { return }

        switch mode {
        case .write, .split:
            // The editor pane's anchor is readable synchronously; in Side by
            // Side both panes are aligned, so the editor is the reliable source.
            deliver(anchor: editorAnchorForPreview(), to: newMode)
        case .read:
            // Read → *: ask the live page first; its capture answers fast or
            // times out to the cached debounced anchor.
            guard !isCapturingPreviewAnchor else { return }
            isCapturingPreviewAnchor = true
            previewViewport.currentAnchor { fresh in
                isCapturingPreviewAnchor = false
                guard mode == .read else { return }
                deliver(anchor: previewAnchorForEditor(fresh: fresh), to: newMode)
            }
        }
    }

    /// Publishes the anchor for the incoming view and flips the mode. The
    /// single-target jump bindings are cleared so a leftover outline/find jump
    /// can never override the fresher viewport anchor. Each direction has its
    /// own anchor binding: the outgoing surface's final `updateNSView` pass
    /// must not be able to consume the incoming surface's target.
    private func deliver(anchor: ViewportAnchor, to newMode: EditorMode) {
        document.jumpLine = nil
        document.jumpHeadingID = nil
        document.jumpFraction = nil
        switch newMode {
        case .read:
            document.editorJumpAnchor = nil
            document.previewJumpAnchor = anchor
        case .write:
            document.previewJumpAnchor = nil
            document.editorJumpAnchor = anchor
        case .split:
            // Land both freshly mounted panes on the same content so Side by
            // Side opens aligned to where the user was.
            document.editorJumpAnchor = anchor
            document.previewJumpAnchor = anchor
        }
        // A mode change starts a clean sync slate.
        splitSyncSource = nil
        mode = newMode
    }

    /// The editor's live viewport anchor (falling back to the last reported
    /// line), completed with the heading/fraction fallbacks the preview needs
    /// when block metadata cannot resolve.
    private func editorAnchorForPreview() -> ViewportAnchor {
        var anchor = editorViewport.currentAnchor() ?? ViewportAnchor(
            sourceLine: editorAnchorLine,
            scrollFraction: fraction(forLine: editorAnchorLine, totalLines: totalLineCount)
        )
        if let line = anchor.sourceLine {
            anchor.fallbackHeadingID = document.rendered.outline.heading(atOrAbove: line)?.id
        }
        return anchor
    }

    /// The preview anchor to apply to the editor: the fresh capture when it
    /// answered, else the cached debounced anchor. A heading-only anchor is
    /// resolved to its source line here, where the outline is known.
    private func previewAnchorForEditor(fresh: ViewportAnchor?) -> ViewportAnchor {
        var anchor = fresh ?? previewAnchor ?? ViewportAnchor()
        if anchor.sourceLine == nil,
           let headingID = anchor.fallbackHeadingID,
           let heading = document.rendered.outline.heading(forID: headingID) {
            anchor.sourceLine = heading.line
            anchor.sourceEndLine = nil
            anchor.intraBlockProgress = 0
        }
        return anchor
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
            editorPane(inSplit: false)
        case .read:
            previewPane(inSplit: false)
        case .split:
            // Editor on the left, live preview on the right, with a draggable
            // divider (HSplitView). Each pane is clamped to a usable minimum.
            HSplitView {
                editorPane(inSplit: true)
                    .frame(minWidth: splitPaneMinWidth)
                previewPane(inSplit: true)
                    .frame(minWidth: splitPaneMinWidth)
            }
        }
    }

    /// The editor surface (with its find bar). In Side by Side it also drives
    /// the preview on scroll and claims focus on interaction; the mode-toggle
    /// shortcut (Esc) is disabled so it cannot accidentally leave split.
    @ViewBuilder
    private func editorPane(inSplit: Bool) -> some View {
        ZStack(alignment: .top) {
            MarkdownEditorView(
                text: $document.text,
                jumpLine: $document.jumpLine,
                jumpFraction: $document.jumpFraction,
                jumpAnchor: $document.editorJumpAnchor,
                viewportReader: editorViewport,
                onAnchorLineChange: { line in
                    editorAnchorLine = line
                    if inSplit { syncEditorToPreview(line: line) }
                },
                onEnterPreview: { if !inSplit { requestMode(.read) } },
                findQuery: $editorFindQuery,
                findNavigation: $editorFindNavigation,
                findReplacement: $editorFindReplacement,
                replaceCommand: $editorReplaceCommand,
                focusToken: editorSurfaceFocusToken,
                focusOnProgrammaticScroll: !inSplit,
                onFindShortcut: { action in
                    if inSplit { focusedPane = .editor }
                    handleEditorFindAction(action)
                },
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
    }

    /// The preview surface (with its find bar). In Side by Side it re-renders in
    /// place as the document changes (`liveUpdate`), drives the editor on scroll,
    /// and claims focus on interaction; the mode-toggle gesture (Cmd+double
    /// click) is disabled so it cannot accidentally leave split.
    @ViewBuilder
    private func previewPane(inSplit: Bool) -> some View {
        ZStack(alignment: .top) {
            MarkdownPreviewView(
                html: document.rendered.html,
                bodyHTML: document.rendered.body,
                baseURL: document.baseURL,
                liveUpdate: inSplit,
                jumpHeadingID: $document.jumpHeadingID,
                jumpFraction: $document.jumpFraction,
                jumpAnchor: $document.previewJumpAnchor,
                viewportReader: previewViewport,
                onAnchorChange: { anchor in
                    previewAnchor = anchor
                    if inSplit { syncPreviewToEditor(anchor: anchor) }
                },
                onEnterEdit: { if !inSplit { requestMode(.write) } },
                onToggleTask: { line, checked in
                    if inSplit { focusedPane = .preview }
                    // Capture the live viewport first so the re-render the
                    // toggle triggers can land back where the user was.
                    previewViewport.currentAnchor { fresh in
                        guard document.toggleTask(atLine: line, to: checked) else { return }
                        document.previewJumpAnchor = fresh ?? previewAnchor
                    }
                },
                findQuery: $previewFindQuery,
                findNavigation: $previewFindNavigation,
                focusToken: previewSurfaceFocusToken,
                onFindShortcut: { action in
                    if inSplit { focusedPane = .preview }
                    handlePreviewFindAction(action)
                },
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

    // MARK: Side by Side scroll synchronization

    /// Editor scrolled: drive the preview to the matching source line. Ignored
    /// while the editor is itself following the preview, so the two cannot
    /// oscillate. The editor only reports a line, so a fresh viewport anchor is
    /// built around it with the section-heading fallback the preview can use.
    private func syncEditorToPreview(line: Int) {
        guard mode == .split, splitSyncSource != .preview else { return }
        markSyncSource(.editor)
        focusedPane = .editor
        let anchor = ViewportAnchor(
            sourceLine: line,
            scrollFraction: fraction(forLine: line, totalLines: totalLineCount),
            fallbackHeadingID: document.rendered.outline.heading(atOrAbove: line)?.id
        )
        editorSyncWork?.cancel()
        let work = DispatchWorkItem { document.previewJumpAnchor = anchor }
        editorSyncWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: work)
    }

    /// Preview scrolled: drive the editor to the matching source line. Ignored
    /// while the preview is itself following the editor. A heading-only anchor
    /// is resolved to its source line here, where the outline is known.
    private func syncPreviewToEditor(anchor: ViewportAnchor) {
        guard mode == .split, splitSyncSource != .editor else { return }
        markSyncSource(.preview)
        focusedPane = .preview
        var resolved = anchor
        if resolved.sourceLine == nil,
           let headingID = resolved.fallbackHeadingID,
           let heading = document.rendered.outline.heading(forID: headingID) {
            resolved.sourceLine = heading.line
            resolved.sourceEndLine = nil
            resolved.intraBlockProgress = 0
        }
        document.editorJumpAnchor = resolved
    }

    /// Marks `pane` as the current sync driver and arms a short cooldown. The
    /// follower's programmatic scroll suppresses its own anchor reporting, and
    /// this guard ignores the single settle-time report that still arrives, so a
    /// drive in one direction cannot bounce back as a drive in the other.
    private func markSyncSource(_ pane: SplitPane) {
        splitSyncSource = pane
        let token = UUID()
        splitSyncToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if splitSyncToken == token {
                splitSyncSource = nil
            }
        }
    }
}

/// The two surfaces of Side by Side mode.
private enum SplitPane {
    case editor
    case preview
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
