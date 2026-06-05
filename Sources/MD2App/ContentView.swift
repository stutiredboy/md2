import MD2Core
import SwiftUI

struct ContentView: View {
    @ObservedObject var document: DocumentStore
    @ObservedObject var settings: AppSettings
    @State private var mode: EditorMode
    @State private var showsOutline: Bool
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

                Picker(settings.text(.mode), selection: $mode) {
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

    @ViewBuilder
    private var editorSurface: some View {
        switch mode {
        case .write:
            MarkdownEditorView(
                text: $document.text,
                jumpLine: $document.jumpLine,
                onEnterPreview: { mode = .read }
            )
        case .read:
            MarkdownPreviewView(
                html: document.rendered.html,
                baseURL: document.baseURL,
                jumpHeadingID: $document.jumpHeadingID,
                onEnterEdit: { mode = .write }
            )
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
