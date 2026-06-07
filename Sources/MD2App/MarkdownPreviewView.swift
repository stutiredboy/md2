import AppKit
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
    /// The current find query; running search whenever it changes.
    @Binding var findQuery: String
    /// A next/previous navigation request; consumed (set to nil) once applied.
    @Binding var findNavigation: FindCommand?
    /// Changes whenever the preview surface should become first responder.
    let focusToken: UUID
    /// Called when the web view receives a standard Find key/menu action before
    /// SwiftUI commands can route it through `DocumentStore`.
    var onFindShortcut: (_ action: FindCommand.Action) -> Void = { _ in }
    /// Reports match count and the 1-based index of the current match (0 when
    /// there are none) back to the find bar.
    var onFindResult: (_ total: Int, _ index: Int) -> Void = { _, _ in }

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
                if (window.__md2FindActive) { return; }
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

            // --- Find (preview, read-only) --------------------------------
            // Walks text nodes and wraps case-insensitive matches in <mark>
            // elements so they can be highlighted and scrolled to. Returns
            // {total, index} so the native find bar can show "i / n". The
            // current match also gets a distinct class. `__md2FindActive`
            // briefly suppresses anchor reporting so programmatic scrolling to a
            // match is not captured as the user's mode-switch anchor.
            var findMarks = [];
            var findCurrent = -1;
            window.__md2FindActive = false;

            (function ensureFindStyle() {
                var style = document.createElement('style');
                style.textContent =
                    'mark.md2-find{background:#ffe066;color:inherit;border-radius:2px;}' +
                    'mark.md2-find-current{background:#ff9f1c;}';
                document.head.appendChild(style);
            })();

            function clearFind() {
                for (var i = 0; i < findMarks.length; i++) {
                    var m = findMarks[i];
                    var parent = m.parentNode;
                    if (!parent) { continue; }
                    parent.replaceChild(document.createTextNode(m.textContent), m);
                    parent.normalize();
                }
                findMarks = [];
                findCurrent = -1;
            }
            window.__md2FindClear = clearFind;

            function setCurrent(index) {
                if (findMarks.length === 0) { return { total: 0, index: 0 }; }
                if (findCurrent >= 0 && findCurrent < findMarks.length) {
                    findMarks[findCurrent].classList.remove('md2-find-current');
                }
                findCurrent = ((index % findMarks.length) + findMarks.length) % findMarks.length;
                var el = findMarks[findCurrent];
                el.classList.add('md2-find-current');
                window.__md2FindActive = true;
                el.scrollIntoView({ block: 'center', inline: 'nearest' });
                clearTimeout(window.__md2FindTimer);
                window.__md2FindTimer = setTimeout(function () {
                    window.__md2FindActive = false;
                }, 400);
                return { total: findMarks.length, index: findCurrent + 1 };
            }

            window.__md2Find = function (query) {
                clearFind();
                if (!query) { return { total: 0, index: 0 }; }
                var lower = query.toLowerCase();
                var walker = document.createTreeWalker(
                    document.body, NodeFilter.SHOW_TEXT, {
                        acceptNode: function (node) {
                            if (!node.nodeValue) { return NodeFilter.FILTER_REJECT; }
                            var p = node.parentNode;
                            if (p && (p.tagName === 'SCRIPT' || p.tagName === 'STYLE' ||
                                      p.tagName === 'MARK')) {
                                return NodeFilter.FILTER_REJECT;
                            }
                            return node.nodeValue.toLowerCase().indexOf(lower) >= 0
                                ? NodeFilter.FILTER_ACCEPT
                                : NodeFilter.FILTER_REJECT;
                        }
                    }
                );
                var targets = [];
                var n;
                while ((n = walker.nextNode())) { targets.push(n); }

                for (var t = 0; t < targets.length; t++) {
                    var node = targets[t];
                    var text = node.nodeValue;
                    var lowerText = text.toLowerCase();
                    var frag = document.createDocumentFragment();
                    var from = 0;
                    var at;
                    while ((at = lowerText.indexOf(lower, from)) >= 0) {
                        if (at > from) {
                            frag.appendChild(document.createTextNode(text.slice(from, at)));
                        }
                        var mark = document.createElement('mark');
                        mark.className = 'md2-find';
                        mark.textContent = text.slice(at, at + query.length);
                        frag.appendChild(mark);
                        findMarks.push(mark);
                        from = at + query.length;
                    }
                    if (from < text.length) {
                        frag.appendChild(document.createTextNode(text.slice(from)));
                    }
                    node.parentNode.replaceChild(frag, node);
                }

                if (findMarks.length === 0) { return { total: 0, index: 0 }; }
                return setCurrent(0);
            };

            window.__md2FindNext = function (forward) {
                if (findMarks.length === 0) { return { total: 0, index: 0 }; }
                return setCurrent(findCurrent + (forward ? 1 : -1));
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

        let webView = PreviewWebView(frame: .zero, configuration: configuration)
        webView.onFindAction = { action in
            context.coordinator.onFindShortcut(action)
        }
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onEnterEdit = onEnterEdit
        context.coordinator.onAnchorChange = onAnchorChange
        context.coordinator.onFindShortcut = onFindShortcut
        context.coordinator.onFindResult = onFindResult

        if let previewWebView = webView as? PreviewWebView {
            previewWebView.onFindAction = { action in
                context.coordinator.onFindShortcut(action)
            }
        }

        if context.coordinator.lastHTML != html || context.coordinator.lastBaseURL != baseURL {
            context.coordinator.lastHTML = html
            context.coordinator.lastBaseURL = baseURL
            context.coordinator.beginLoading()
            context.coordinator.lastFindQuery = nil
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

        if context.coordinator.lastFindQuery != findQuery {
            context.coordinator.lastFindQuery = findQuery
            context.coordinator.runFindWhenReady(findQuery, in: webView)
        }

        if let navigation = findNavigation {
            navigateFind(navigation, in: webView, coordinator: context.coordinator)
            self.findNavigation = nil
        }

        if context.coordinator.lastFocusToken != focusToken {
            context.coordinator.lastFocusToken = focusToken
            DispatchQueue.main.async {
                webView.window?.makeFirstResponder(webView)
            }
        }
    }

    /// Highlights all matches of `query` and reports the JavaScript result.
    private static func evaluateFind(
        _ query: String,
        in webView: WKWebView,
        completion: @escaping (Any?) -> Void
    ) {
        let escaped = Self.escapeForJS(query)
        webView.evaluateJavaScript("window.__md2Find('\(escaped)');") { result, _ in
            completion(result)
        }
    }

    /// Moves to the next or previous match and reports the result.
    private func navigateFind(_ command: FindCommand, in webView: WKWebView, coordinator: Coordinator) {
        let forward = command.action != .previous
        webView.evaluateJavaScript("window.__md2FindNext(\(forward));") { result, _ in
            coordinator.reportFindResult(result)
        }
    }

    private static func escapeForJS(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")
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
        var onFindShortcut: (_ action: FindCommand.Action) -> Void = { _ in }
        var onFindResult: (_ total: Int, _ index: Int) -> Void = { _, _ in }
        var lastFindQuery: String?
        var lastFocusToken: UUID?

        private var isLoaded = false
        private var pendingScroll: ModeSwitchAnchor?
        private var pendingFindQuery: String?

        /// Marks the page as loading before WebKit callbacks arrive. This prevents
        /// a same-query search from running against the previous document body.
        func beginLoading() {
            isLoaded = false
        }

        /// Runs a preview search immediately when the page is ready, otherwise
        /// remembers the latest query and applies it after `didFinish`.
        func runFindWhenReady(_ query: String, in webView: WKWebView) {
            pendingFindQuery = query
            if isLoaded {
                applyPendingFind(in: webView)
            }
        }

        /// Parses the `{total, index}` object returned by the JS find helpers and
        /// forwards it to the find bar.
        func reportFindResult(_ result: Any?) {
            guard let dict = result as? [String: Any] else {
                onFindResult(0, 0)
                return
            }
            let total = (dict["total"] as? NSNumber)?.intValue ?? 0
            let index = (dict["index"] as? NSNumber)?.intValue ?? 0
            onFindResult(total, index)
        }

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
            applyPendingFind(in: webView)
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

        private func applyPendingFind(in webView: WKWebView) {
            guard let query = pendingFindQuery else { return }
            pendingFindQuery = nil
            MarkdownPreviewView.evaluateFind(query, in: webView) { [weak self] result in
                self?.reportFindResult(result)
            }
        }

        deinit {
            if let previewFileURL {
                try? FileManager.default.removeItem(at: previewFileURL)
            }
        }
    }
}

private final class PreviewWebView: WKWebView {
    var onFindAction: ((FindCommand.Action) -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if let action = findAction(for: event) {
            onFindAction?(action)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    @objc(performFindPanelAction:)
    func md2PerformFindPanelAction(_ sender: Any?) {
        onFindAction?(findAction(for: sender))
    }

    override func performTextFinderAction(_ sender: Any?) {
        onFindAction?(findAction(for: sender))
    }

    private func findAction(for event: NSEvent) -> FindCommand.Action? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command),
              !flags.contains(.control),
              !flags.contains(.option),
              let key = event.charactersIgnoringModifiers?.lowercased() else {
            return nil
        }

        switch key {
        case "f":
            return .show
        case "g":
            return flags.contains(.shift) ? .previous : .next
        default:
            return nil
        }
    }

    private func findAction(for sender: Any?) -> FindCommand.Action {
        guard let menuItem = sender as? NSMenuItem,
              let textFinderAction = NSTextFinder.Action(rawValue: menuItem.tag) else {
            return .show
        }

        switch textFinderAction {
        case .nextMatch:
            return .next
        case .previousMatch:
            return .previous
        case .showReplaceInterface:
            return .showReplace
        default:
            return .show
        }
    }
}
