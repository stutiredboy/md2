import MD2Core
import SwiftUI

struct ContentView: View {
    @ObservedObject var document: DocumentStore
    @State private var mode: EditorMode = .write
    @State private var showsOutline = true

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if showsOutline {
                    OutlineSidebar(
                        headings: document.rendered.outline,
                        selectedHeadingID: document.jumpHeadingID,
                        onSelect: document.jump(to:)
                    )
                    Divider()
                }

                editorSurface
            }

            Divider()
            StatusBar(stats: document.rendered.stats, url: document.fileURL)
        }
        .frame(minWidth: 780, minHeight: 540)
        .navigationTitle(document.displayTitle)
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    showsOutline.toggle()
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help(showsOutline ? "Hide outline" : "Show outline")
            }

            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    document.newDocument()
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .help("New")

                Button {
                    document.openDocument()
                } label: {
                    Image(systemName: "folder")
                }
                .help("Open")

                Button {
                    document.save()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .help("Save")

                Picker("Mode", selection: $mode) {
                    Image(systemName: "pencil").tag(EditorMode.write)
                    Image(systemName: "doc.richtext").tag(EditorMode.read)
                }
                .pickerStyle(.segmented)
                .frame(width: 92)
                .help("Write or read")
            }
        }
        .alert(item: $document.alert) { alert in
            Alert(
                title: Text(alert.message),
                message: Text(alert.detail),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    @ViewBuilder
    private var editorSurface: some View {
        switch mode {
        case .write:
            MarkdownEditorView(
                text: $document.text,
                jumpLine: $document.jumpLine
            )
        case .read:
            MarkdownPreviewView(
                html: document.rendered.html,
                baseURL: document.baseURL,
                jumpHeadingID: $document.jumpHeadingID
            )
        }
    }
}

private struct OutlineSidebar: View {
    let headings: [Heading]
    let selectedHeadingID: String?
    let onSelect: (Heading) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Outline")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 8)

            if headings.isEmpty {
                Text("No headings")
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

    var body: some View {
        HStack(spacing: 14) {
            Text("\(stats.words) words")
            Text("\(stats.characters) chars")
            Text("\(stats.lines) lines")
            Text("\(stats.readingMinutes) min read")

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
