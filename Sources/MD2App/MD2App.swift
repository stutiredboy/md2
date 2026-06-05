import MD2AppSupport
import SwiftUI

@main
struct MD2Application: App {
    @NSApplicationDelegateAdaptor(MD2AppDelegate.self) private var appDelegate

    init() {
        if DirectLaunchBootstrap.relaunchFromAppBundleIfNeeded() {
            exit(EXIT_SUCCESS)
        }
    }

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New") {
                    appDelegate.documentStore.newDocument()
                }
                .keyboardShortcut("n")

                Button("Open...") {
                    appDelegate.documentStore.openDocument()
                }
                .keyboardShortcut("o")
            }

            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    appDelegate.documentStore.save()
                }
                .keyboardShortcut("s")

                Button("Save As...") {
                    appDelegate.documentStore.saveAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }
    }
}
