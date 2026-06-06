import MD2Core
import SwiftUI
import WebKit

struct MarkdownPreviewView: NSViewRepresentable {
    let html: String
    let baseURL: URL?
    @Binding var jumpHeadingID: String?
    /// Fraction (0...1) to scroll to after load when no heading anchor applies.
    @Binding var jumpFraction: Double?
    /// Reports the id of the heading at the top of the viewport (or `nil` with a
    /// scroll fraction when none qualifies) on scroll, so a mode switch can
    /// anchor to it.
    var onAnchorChange: (_ headingID: String?, _ fraction: Double) -> Void = { _, _ in }
    /// Called on a Cmd+double-click, requesting a switch to edit mode.
    var onEnterEdit: () -> Void = {}

    private static let enterEditMessageName = "enterEdit"
    private static let anchorMessageName = "anchorChange"

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        // Forward Cmd+double-click in the rendered page back to native so the
        // surrounding view can switch into edit mode. Also report the heading at
        // the top of the viewport (debounced) so a mode switch can anchor to it,
        // and expose reflow-resilient scroll helpers the native side invokes
        // after a mode switch.
        let source = """
        document.addEventListener('dblclick', function(event) {
            if (event.metaKey) {
                window.webkit.messageHandlers.\(Self.enterEditMessageName).postMessage(null);
            }
        });
        (function () {
            // Suppress anchor reporting while we are programmatically scrolling,
            // so a mode-switch scroll is never captured back as the user's anchor.
            var suppressUntil = 0;

            function topAnchor() {
                if (Date.now() < suppressUntil) { return; }
                var headings = document.querySelectorAll('h1,h2,h3,h4,h5,h6');
                // The "current" section is the last heading at or above the top,
                // but a heading the reader has scrolled to just under the top edge
                // should also count — otherwise we report the previous section.
                // So accept headings down to a zone below the top and pick the one
                // nearest the top.
                var zone = Math.max(120, window.innerHeight * 0.25);
                var id = null;
                for (var i = 0; i < headings.length; i++) {
                    if (!headings[i].id) { continue; }
                    var top = headings[i].getBoundingClientRect().top;
                    if (top <= zone) {
                        id = headings[i].id;
                    } else {
                        break;
                    }
                }
                var max = document.documentElement.scrollHeight - window.innerHeight;
                var fraction = max > 0 ? window.scrollY / max : 0;
                window.webkit.messageHandlers.\(Self.anchorMessageName).postMessage({
                    id: id, fraction: fraction
                });
            }
            var pending = false;
            window.addEventListener('scroll', function () {
                if (pending) { return; }
                pending = true;
                setTimeout(function () { pending = false; topAnchor(); }, 80);
            }, { passive: true });
            window.addEventListener('load', topAnchor);

            // Keeps the viewport pinned to a target while the document is still
            // reflowing. Async KaTeX/Mermaid/diagram rendering settles over a
            // second or two after load. `getTargetY` returns the absolute Y the
            // viewport should scroll to (or null if not measurable yet). We only
            // re-scroll when that target actually MOVES — i.e. when content above
            // the anchor reflows. Content below the anchor changing the total
            // height does not move the target, so we don't scroll (avoiding a
            // pointless late jump). We stop on a user scroll or once stable.
            function keepPinned(getTargetY) {
                suppressUntil = Date.now() + 2600;
                var cancelled = false;
                function onUser() { cancelled = true; }
                // Fast-path cancels for common gestures; the scrollY check below
                // is the robust catch-all (covers scrollbar drags, etc.).
                window.addEventListener('wheel', onUser, { passive: true, once: true });
                window.addEventListener('keydown', onUser, { once: true });
                window.addEventListener('touchmove', onUser, { passive: true, once: true });

                var lastTargetY = null;
                var expectedY = 0;
                var started = false;
                var stableFrames = 0;
                var start = Date.now();
                function done() {
                    cancelled = true;
                    suppressUntil = 0;
                    // Report the final resting position so the captured anchor
                    // reflects where we actually landed (e.g. after an outline
                    // click programmatically scrolled the preview).
                    topAnchor();
                }
                function step() {
                    if (cancelled) { return; }
                    if (started && Math.abs(window.scrollY - expectedY) > 2) {
                        // Scroll position changed but we didn't move it: the user
                        // scrolled. Yield and stop re-anchoring.
                        done();
                        return;
                    }
                    var targetY = getTargetY();
                    if (targetY !== null && (lastTargetY === null || Math.abs(targetY - lastTargetY) > 1)) {
                        // First positioning, or the anchor moved (content above
                        // reflowed): scroll to it.
                        lastTargetY = targetY;
                        stableFrames = 0;
                        var maxY = document.documentElement.scrollHeight - window.innerHeight;
                        window.scrollTo(0, Math.min(Math.max(0, targetY), Math.max(0, maxY)));
                        expectedY = window.scrollY;
                        started = true;
                    } else {
                        stableFrames++;
                    }
                    if (stableFrames < 8 && (Date.now() - start) < 2500) {
                        requestAnimationFrame(step);
                    } else {
                        done();
                    }
                }
                requestAnimationFrame(step);
            }

            window.__md2ScrollToHeading = function (id) {
                keepPinned(function () {
                    var el = document.getElementById(id);
                    if (!el) { return null; }
                    // Absolute document Y of the element's top.
                    return el.getBoundingClientRect().top + window.scrollY;
                });
            };
            window.__md2ScrollToFraction = function (f) {
                var pinned = false;
                keepPinned(function () {
                    // Fraction maps to total height, which keeps changing as the
                    // page renders; pin once to avoid chasing it.
                    if (pinned) { return null; }
                    pinned = true;
                    var max = document.documentElement.scrollHeight - window.innerHeight;
                    return max > 0 ? max * f : 0;
                });
            };
        })();
        """
        let userScript = WKUserScript(
            source: source,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(userScript)
        configuration.userContentController.add(context.coordinator, name: Self.enterEditMessageName)
        configuration.userContentController.add(context.coordinator, name: Self.anchorMessageName)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onEnterEdit = onEnterEdit
        context.coordinator.onAnchorChange = onAnchorChange

        if context.coordinator.lastHTML != html || context.coordinator.lastBaseURL != baseURL {
            context.coordinator.lastHTML = html
            context.coordinator.lastBaseURL = baseURL
            // Load with the pending heading as a URL fragment so WebKit scrolls
            // to it natively during parsing. This is the only thing that can
            // position the page before the inlined diagram/math engine scripts
            // finish executing (which blocks all JavaScript, including our own
            // scroll code, for several seconds on engine-heavy documents).
            load(html, baseURL: baseURL, fragment: jumpHeadingID, in: webView, coordinator: context.coordinator)
        }

        // Heading/fraction targets are also applied once the page has finished
        // loading, which re-affirms the position after async rendering reflows
        // the layout. On a fresh mode switch the web view is still loading when
        // the binding arrives, so the coordinator holds the target and applies it
        // on `didFinish`; if already loaded it applies immediately.
        if let jumpHeadingID {
            context.coordinator.setPendingScroll(.heading(id: jumpHeadingID), in: webView)
            self.jumpHeadingID = nil
            self.jumpFraction = nil
        } else if let jumpFraction {
            context.coordinator.setPendingScroll(.fraction(jumpFraction), in: webView)
            self.jumpHeadingID = nil
            self.jumpFraction = nil
        }
    }

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator()
        coordinator.onEnterEdit = onEnterEdit
        return coordinator
    }

    /// Loads the rendered HTML into the web view.
    ///
    /// `loadHTMLString(_:baseURL:)` does not grant the web view read access to the
    /// file system, so relative resources such as `![](images/foo.png)` never load.
    /// When the document lives on disk we instead write the HTML to a temporary file
    /// inside the document's directory and load it via `loadFileURL`, granting read
    /// access to that directory so relative image paths resolve correctly.
    private func load(_ html: String, baseURL: URL?, fragment: String?, in webView: WKWebView, coordinator: Coordinator) {
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
            // `loadFileRequest(_:allowingReadAccessTo:)` grants read access to the
            // document directory; the request URL carries the anchor fragment so
            // the browser scrolls to it as the DOM is built.
            let request = URLRequest(url: fragmentURL(previewURL, fragment: fragment))
            webView.loadFileRequest(request, allowingReadAccessTo: baseURL)
        } catch {
            webView.loadHTMLString(html, baseURL: baseURL)
        }
    }

    /// Appends a percent-encoded fragment to a file URL, if provided.
    private func fragmentURL(_ url: URL, fragment: String?) -> URL {
        guard let fragment,
              let encoded = fragment.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed),
              let withFragment = URL(string: url.absoluteString + "#" + encoded) else {
            return url
        }
        return withFragment
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var lastHTML = ""
        var lastBaseURL: URL?
        let previewID = UUID().uuidString
        var previewFileURL: URL?
        var onEnterEdit: () -> Void = {}
        var onAnchorChange: (_ headingID: String?, _ fraction: Double) -> Void = { _, _ in }

        private var isLoaded = false
        private var pendingScroll: ModeSwitchAnchor?

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            switch message.name {
            case MarkdownPreviewView.enterEditMessageName:
                onEnterEdit()
            case MarkdownPreviewView.anchorMessageName:
                guard let body = message.body as? [String: Any] else { return }
                let id = body["id"] as? String
                let fraction = (body["fraction"] as? NSNumber)?.doubleValue ?? 0
                onAnchorChange(id, fraction)
            default:
                break
            }
        }

        // MARK: Deferred scrolling

        /// Records a scroll target and applies it now if the page has finished
        /// loading, otherwise defers it to `didFinish`.
        func setPendingScroll(_ anchor: ModeSwitchAnchor, in webView: WKWebView) {
            pendingScroll = anchor
            if isLoaded {
                applyPendingScroll(in: webView)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoaded = true
            applyPendingScroll(in: webView)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            // A new document started loading; hold scrolling until it finishes.
            isLoaded = false
        }

        private func applyPendingScroll(in webView: WKWebView) {
            guard let anchor = pendingScroll else { return }
            pendingScroll = nil

            switch anchor {
            case let .heading(id):
                let escapedID = id
                    .replacingOccurrences(of: "\\", with: "\\\\")
                    .replacingOccurrences(of: "'", with: "\\'")
                webView.evaluateJavaScript("window.__md2ScrollToHeading('\(escapedID)');")
            case let .fraction(value):
                let clamped = min(max(value, 0), 1)
                webView.evaluateJavaScript("window.__md2ScrollToFraction(\(clamped));")
            case .line:
                break
            }
        }

        deinit {
            if let previewFileURL {
                try? FileManager.default.removeItem(at: previewFileURL)
            }
        }
    }
}
