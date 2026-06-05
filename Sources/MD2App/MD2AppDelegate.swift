import AppKit
import MD2AppSupport
import SwiftUI

@MainActor
final class MD2AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let documentStore = DocumentStore()
    let settings = AppSettings()

    private var pendingOpenURLs: [URL] = []
    private var window: NSWindow?
    private let activationController = LaunchActivationController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        showMainWindow()
        documentStore.loadInitialFileFromArguments()
        activationController.activateAfterLaunch()
        LaunchHealthReporter.write("didFinishLaunching")
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        showMainWindow()
        activationController.activateAfterLaunch()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard !urls.isEmpty else { return }

        documentStore.open(urls[0])
        showMainWindow()

        activationController.activateAfterLaunch()
    }

    private func showMainWindow() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let contentView = ContentView(document: documentStore, settings: settings)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = documentStore.displayTitle
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        self.window = window

        guard let firstURL = pendingOpenURLs.first else {
            return
        }

        pendingOpenURLs.removeAll()
        documentStore.open(firstURL)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        confirmDiscardOrSaveIfNeeded()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        confirmDiscardOrSaveIfNeeded() ? .terminateNow : .terminateCancel
    }

    private func confirmDiscardOrSaveIfNeeded() -> Bool {
        guard documentStore.isDirty else {
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
            return documentStore.save()
        case .alertSecondButtonReturn:
            return false
        default:
            return true
        }
    }
}
