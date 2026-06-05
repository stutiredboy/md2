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
            webView.loadHTMLString(html, baseURL: baseURL)
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
    }
}
