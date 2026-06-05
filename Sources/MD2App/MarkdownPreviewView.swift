import SwiftUI
import WebKit

struct MarkdownPreviewView: NSViewRepresentable {
    let html: String
    let baseURL: URL?
    @Binding var jumpHeadingID: String?

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastHTML != html || context.coordinator.lastBaseURL != baseURL {
            context.coordinator.lastHTML = html
            context.coordinator.lastBaseURL = baseURL
            load(html, baseURL: baseURL, in: webView, coordinator: context.coordinator)
        }

        if let jumpHeadingID {
            let target = jumpHeadingID
            DispatchQueue.main.async {
                scroll(to: target, in: webView)
                self.jumpHeadingID = nil
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// Loads the rendered HTML into the web view.
    ///
    /// `loadHTMLString(_:baseURL:)` does not grant the web view read access to the
    /// file system, so relative resources such as `![](images/foo.png)` never load.
    /// When the document lives on disk we instead write the HTML to a temporary file
    /// inside the document's directory and load it via `loadFileURL`, granting read
    /// access to that directory so relative image paths resolve correctly.
    private func load(_ html: String, baseURL: URL?, in webView: WKWebView, coordinator: Coordinator) {
        guard let baseURL, baseURL.isFileURL else {
            webView.loadHTMLString(html, baseURL: baseURL)
            return
        }

        let previewURL = baseURL.appendingPathComponent(".md2-preview-\(coordinator.previewID).html")
        do {
            if let previous = coordinator.previewFileURL, previous != previewURL {
                try? FileManager.default.removeItem(at: previous)
            }
            try html.write(to: previewURL, atomically: true, encoding: .utf8)
            coordinator.previewFileURL = previewURL
            webView.loadFileURL(previewURL, allowingReadAccessTo: baseURL)
        } catch {
            webView.loadHTMLString(html, baseURL: baseURL)
        }
    }

    private func scroll(to id: String, in webView: WKWebView) {
        let escapedID = id
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let script = "document.getElementById('\(escapedID)')?.scrollIntoView({ behavior: 'smooth', block: 'start' });"
        webView.evaluateJavaScript(script)
    }

    final class Coordinator {
        var lastHTML = ""
        var lastBaseURL: URL?
        let previewID = UUID().uuidString
        var previewFileURL: URL?

        deinit {
            if let previewFileURL {
                try? FileManager.default.removeItem(at: previewFileURL)
            }
        }
    }
}
