import AppKit
import Combine
import MD2AppSupport
import SwiftUI

@MainActor
final class MD2AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let settings = AppSettings()

    private var documentWindows: [DocumentWindow] = []
    private let activationController = LaunchActivationController()

    /// The document store backing the frontmost window. Menu commands such as
    /// Save act on whichever document the user is currently looking at.
    var currentDocumentStore: DocumentStore? {
        if let keyWindow = NSApp.keyWindow,
           let match = documentWindows.first(where: { $0.window == keyWindow }) {
            return match.store
        }
        return documentWindows.first?.store
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let url = fileURLFromLaunchArguments() {
            openInNewWindow(url)
        } else if documentWindows.isEmpty {
            // Only fall back to a blank document if nothing was already opened —
            // e.g. `application(_:open:)` may have fired first when launched by
            // double-clicking or right-clicking a file in Finder.
            newDocument()
        }
        activationController.activateAfterLaunch()
        LaunchHealthReporter.write("didFinishLaunching")
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if documentWindows.isEmpty {
            newDocument()
        } else {
            documentWindows.last?.window.makeKeyAndOrderFront(nil)
        }
        activationController.activateAfterLaunch()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            openInNewWindow(url)
        }
        activationController.activateAfterLaunch()
    }

    // MARK: - Document actions

    /// Opens a fresh, empty document in its own window.
    func newDocument() {
        makeDocumentWindow(store: DocumentStore()).window.makeKeyAndOrderFront(nil)
    }

    /// Closes the frontmost document window in response to ⌘W. Routing through
    /// `performClose(_:)` (rather than `close()`) drives the window through
    /// `windowShouldClose(_:)`, so the existing unsaved-changes prompt runs and
    /// no save/discard logic is duplicated. No-ops safely when no document
    /// window is focused.
    func closeCurrentDocument() {
        let target: NSWindow?
        if let keyWindow = NSApp.keyWindow {
            // Only act when the focused window is one of our document windows;
            // when something else is key (e.g. Settings) leave documents alone.
            target = documentWindows.first(where: { $0.window == keyWindow })?.window
        } else {
            // No key window at all — fall back to the most recent document window.
            target = documentWindows.first?.window
        }
        target?.performClose(nil)
    }

    /// Presents an open panel and loads every selected file, each in its own window.
    func openDocument() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = DocumentStore.markdownTypes

        guard panel.runModal() == .OK else { return }

        for url in panel.urls {
            openInNewWindow(url)
        }
    }

    /// Loads `url` into a window. If it is already open, that window is brought
    /// to the front; otherwise an untouched starter window is reused or a new
    /// one is created.
    private func openInNewWindow(_ url: URL) {
        if let existing = documentWindows.first(where: { $0.store.fileURL == url }) {
            existing.window.makeKeyAndOrderFront(nil)
            return
        }

        if let reusable = documentWindows.first(where: { $0.store.isReusableEmptyDocument }) {
            reusable.store.open(url)
            reusable.window.makeKeyAndOrderFront(nil)
            return
        }

        let documentWindow = makeDocumentWindow(store: DocumentStore())
        documentWindow.store.open(url)
        documentWindow.window.makeKeyAndOrderFront(nil)
    }

    // MARK: - Window management

    @discardableResult
    private func makeDocumentWindow(store: DocumentStore) -> DocumentWindow {
        let contentView = ContentView(
            document: store,
            settings: settings,
            onOpen: { [weak self] in self?.openDocument() }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = store.displayTitle
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: contentView)
        // Let macOS group document windows into native tabs when the user
        // prefers tabs; they can always be torn off into separate windows.
        window.tabbingMode = .automatic
        window.tabbingIdentifier = "MD2Document"

        if let previous = documentWindows.last?.window {
            var origin = previous.frame.origin
            origin = window.cascadeTopLeft(from: NSPoint(x: origin.x, y: origin.y + previous.frame.height))
            window.setFrameTopLeftPoint(origin)
        } else {
            window.center()
        }

        let documentWindow = DocumentWindow(window: window, store: store)
        documentWindows.append(documentWindow)
        return documentWindow
    }

    private func fileURLFromLaunchArguments() -> URL? {
        let arguments = CommandLine.arguments.dropFirst()
        guard let path = arguments.first(where: { !$0.hasPrefix("-") }) else {
            return nil
        }

        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let store = documentWindows.first(where: { $0.window == sender })?.store else {
            return true
        }
        return confirmDiscardOrSaveIfNeeded(for: store)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        documentWindows.removeAll { $0.window == window }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        for documentWindow in documentWindows where documentWindow.store.isDirty {
            documentWindow.window.makeKeyAndOrderFront(nil)
            if !confirmDiscardOrSaveIfNeeded(for: documentWindow.store) {
                return .terminateCancel
            }
        }
        return .terminateNow
    }

    private func confirmDiscardOrSaveIfNeeded(for store: DocumentStore) -> Bool {
        guard store.isDirty else {
            return true
        }

        let alert = NSAlert()
        alert.messageText = settings.text(.unsavedChangesTitle)
        alert.informativeText = settings.text(.unsavedChangesMessage)
        alert.alertStyle = .warning
        alert.addButton(withTitle: settings.text(.save))
        alert.addButton(withTitle: settings.text(.cancel))
        alert.addButton(withTitle: settings.text(.dontSave))

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return store.save()
        case .alertSecondButtonReturn:
            return false
        default:
            return true
        }
    }
}

/// Pairs an `NSWindow` with the document it presents and keeps the window's
/// title in sync with the document (filename and unsaved-changes marker).
@MainActor
private final class DocumentWindow {
    let window: NSWindow
    let store: DocumentStore
    private var cancellable: AnyCancellable?

    init(window: NSWindow, store: DocumentStore) {
        self.window = window
        self.store = store
        cancellable = store.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.window.title = self.store.displayTitle
                self.window.isDocumentEdited = self.store.isDirty
                self.window.representedURL = self.store.fileURL
            }
        }
    }
}
