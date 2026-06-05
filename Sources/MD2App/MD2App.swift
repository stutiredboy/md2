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
            SettingsView(settings: appDelegate.settings)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(appDelegate.settings.text(.new)) {
                    appDelegate.documentStore.newDocument()
                }
                .keyboardShortcut("n")

                Button(appDelegate.settings.text(.open)) {
                    appDelegate.documentStore.openDocument()
                }
                .keyboardShortcut("o")
            }

            CommandGroup(replacing: .saveItem) {
                Button(appDelegate.settings.text(.save)) {
                    appDelegate.documentStore.save()
                }
                .keyboardShortcut("s")

                Button(appDelegate.settings.text(.saveAs)) {
                    appDelegate.documentStore.saveAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }
    }
}
