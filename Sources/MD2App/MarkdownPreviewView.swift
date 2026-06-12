import AppKit
import MD2Core
import SwiftUI
import WebKit

/// Hands the surrounding view a way to ask the *live* preview page for its
/// current viewport anchor at the instant a mode switch is requested, instead
/// of relying on the last (possibly stale) debounced scroll callback.
@MainActor
final class PreviewViewportReader {
    fileprivate var capture: ((_ completion: @escaping (ViewportAnchor?) -> Void) -> Void)?

    /// Asks the live web view for its current anchor. Completes with `nil`
    /// when the preview is not mounted or does not answer within the capture
    /// timeout (e.g. the page is still executing heavy engine scripts).
    func currentAnchor(completion: @escaping (ViewportAnchor?) -> Void) {
        guard let capture else {
            completion(nil)
            return
        }
        capture(completion)
    }
}

struct MarkdownPreviewView: NSViewRepresentable {
    let html: String
    let baseURL: URL?
    @Binding var jumpHeadingID: String?
    /// Fraction (0...1) to scroll to after load when no heading anchor applies.
    @Binding var jumpFraction: Double?
    /// Mode-switch viewport anchor to apply after load; takes precedence over
    /// `jumpHeadingID`/`jumpFraction` and is consumed once handed off.
    @Binding var jumpAnchor: ViewportAnchor?
    /// Exposes on-demand capture of the live viewport anchor for mode switches.
    var viewportReader: PreviewViewportReader?
    /// Reports the viewport-context anchor at the top of the viewport
    /// (debounced) on scroll, so a mode switch can fall back to it.
    var onAnchorChange: (_ anchor: ViewportAnchor) -> Void = { _ in }
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

    /// Filename pieces for the temporary preview file written alongside the
    /// document (kept in the document directory so relative image paths resolve
    /// under the granted read access).
    private static let previewFilePrefix = ".md2-preview-"
    private static let previewFileSuffix = ".html"
    /// Preview files older than this are treated as leftovers from a prior
    /// session/crash and swept. The age gate keeps a live sibling window's file
    /// (rewritten on every render) safe.
    private static let stalePreviewAge: TimeInterval = 3600

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
            // Vertical band below the viewport top sampled for the block the
            // user is reading: small enough to track the top of the viewport,
            // large enough to bridge the margins between blocks.
            var ANCHOR_BAND = 64;

            // The section heading at/above the top of the viewport — kept as
            // the compatibility fallback when block metadata cannot resolve.
            // Headings just under the top edge also count, otherwise we would
            // report the previous section.
            function headingAtTop() {
                var headings = document.querySelectorAll('h1,h2,h3,h4,h5,h6');
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
                return id;
            }

            // Captures the viewport-context anchor: the deepest rendered block
            // (carrying data-md2-source-line) whose top sits at/above a small
            // band below the viewport top, plus intra-block progress and the
            // heading/fraction fallbacks.
            function captureAnchor() {
                var bandY = Math.min(ANCHOR_BAND, window.innerHeight * 0.25);
                var max = document.documentElement.scrollHeight - window.innerHeight;
                var fraction = max > 0 ? Math.min(1, Math.max(0, window.scrollY / max)) : 0;
                var anchor = {
                    line: null, endLine: null, progress: 0, inset: 0,
                    fraction: fraction, id: headingAtTop()
                };

                var nodes = document.querySelectorAll('[data-md2-source-line]');
                var best = null;
                var bestRect = null;
                for (var i = 0; i < nodes.length; i++) {
                    var rect = nodes[i].getBoundingClientRect();
                    if (rect.height <= 0) { continue; }
                    // The last element in document order starting at/above the
                    // band is the deepest block containing the viewport top.
                    if (rect.top <= bandY) { best = nodes[i]; bestRect = rect; }
                }
                if (!best) { return anchor; }

                var start = parseInt(best.getAttribute('data-md2-source-line'), 10);
                if (isNaN(start)) { return anchor; }
                var endAttr = best.getAttribute('data-md2-source-end-line');
                var end = endAttr ? parseInt(endAttr, 10) : start;
                var progress = bestRect.height > 0
                    ? (bandY - bestRect.top) / bestRect.height
                    : 0;
                anchor.line = start;
                anchor.endLine = isNaN(end) ? start : end;
                anchor.progress = Math.min(1, Math.max(0, progress));
                anchor.inset = Math.max(0, bestRect.top);
                return anchor;
            }
            window.__md2CaptureAnchor = captureAnchor;

            function topAnchor() {
                if (Date.now() < suppressUntil) { return; }
                if (window.__md2FindActive) { return; }
                window.webkit.messageHandlers.\(Self.anchorMessageName).postMessage(captureAnchor());
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

            // Absolute document Y for a 1-based source line: the deepest block
            // whose span starts at/above the line, advanced by the line's
            // position within the block's span, minus a small inset so the
            // target never sits flush against the top edge. Returns null when
            // no block metadata resolves (caller falls back to heading/fraction).
            function sourceLineTargetY(line) {
                if (!line || line < 1) { return null; }
                var nodes = document.querySelectorAll('[data-md2-source-line]');
                var best = null;
                var bestRect = null;
                var bestStart = -1;
                for (var i = 0; i < nodes.length; i++) {
                    var start = parseInt(nodes[i].getAttribute('data-md2-source-line'), 10);
                    if (isNaN(start) || start > line) { continue; }
                    var rect = nodes[i].getBoundingClientRect();
                    if (rect.height <= 0 && rect.width <= 0) { continue; }
                    // Later elements in document order win ties so the deepest
                    // nested block (e.g. a paragraph in a blockquote) is chosen.
                    if (start >= bestStart) { best = nodes[i]; bestRect = rect; bestStart = start; }
                }
                if (!best) { return null; }
                if (line <= 1) { return 0; }
                var endAttr = best.getAttribute('data-md2-source-end-line');
                var end = endAttr ? parseInt(endAttr, 10) : bestStart;
                var offset = 0;
                if (!isNaN(end) && end > bestStart && line > bestStart) {
                    offset = Math.min(1, (line - bestStart) / (end - bestStart)) * bestRect.height;
                }
                var inset = 20;
                return Math.max(0, bestRect.top + window.scrollY + offset - inset);
            }

            // Mode-switch destination: land on the block containing the target
            // source line, with heading and proportional-fraction fallbacks.
            // The block target is re-resolved on every pinning frame so async
            // math/diagram reflow above it is tracked; the fraction fallback
            // pins once because it chases the still-changing total height.
            window.__md2ScrollToViewportAnchor = function (payload) {
                var fractionPinned = false;
                keepPinned(function () {
                    var targetY = sourceLineTargetY(payload.line);
                    if (targetY !== null) { return targetY; }
                    if (payload.headingId) {
                        var el = document.getElementById(payload.headingId);
                        if (el) { return el.getBoundingClientRect().top + window.scrollY; }
                    }
                    if (fractionPinned) { return null; }
                    fractionPinned = true;
                    var max = document.documentElement.scrollHeight - window.innerHeight;
                    var f = Math.min(1, Math.max(0, payload.fraction || 0));
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

        let coordinator = context.coordinator
        viewportReader?.capture = { [weak webView, weak coordinator] completion in
            guard let webView, let coordinator else {
                completion(nil)
                return
            }
            coordinator.captureAnchor(in: webView, completion: completion)
        }

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

        let coordinator = context.coordinator
        viewportReader?.capture = { [weak webView, weak coordinator] completion in
            guard let webView, let coordinator else {
                completion(nil)
                return
            }
            coordinator.captureAnchor(in: webView, completion: completion)
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
            // scroll code, for several seconds on engine-heavy documents). A
            // viewport anchor's fallback heading gives the same early, coarse
            // position; the block/source-line target then refines it.
            load(
                html,
                baseURL: baseURL,
                fragment: jumpAnchor?.fallbackHeadingID ?? jumpHeadingID,
                in: webView,
                coordinator: context.coordinator
            )
        }

        // Anchor/heading/fraction targets are also applied once the page has
        // finished loading, which re-affirms the position after async rendering
        // reflows the layout. On a fresh mode switch the web view is still
        // loading when the binding arrives, so the coordinator holds the target
        // and applies it on `didFinish`; if already loaded it applies immediately.
        if let jumpAnchor {
            context.coordinator.setPendingScroll(.viewport(jumpAnchor), in: webView)
            self.jumpAnchor = nil
            self.jumpHeadingID = nil
            self.jumpFraction = nil
        } else if let jumpHeadingID {
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

        let previewURL = baseURL.appendingPathComponent(
            "\(Self.previewFilePrefix)\(coordinator.previewID)\(Self.previewFileSuffix)"
        )
        do {
            if let previous = coordinator.previewFileURL, previous != previewURL {
                try? FileManager.default.removeItem(at: previous)
            }
            sweepStalePreviewFiles(in: baseURL, keeping: previewURL)
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

    /// Removes stale `.md2-preview-*.html` leftovers in `directory` — files this
    /// app wrote in a prior session that a normal teardown would have cleaned but
    /// a crash/force-quit left behind. Never removes `keeping` (the file about to
    /// be loaded) or any file modified within `stalePreviewAge`, so a live sibling
    /// window's preview file is left intact.
    private func sweepStalePreviewFiles(in directory: URL, keeping: URL) {
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: []
        ) else {
            return
        }

        let cutoff = Date().addingTimeInterval(-Self.stalePreviewAge)
        for url in entries {
            let name = url.lastPathComponent
            guard name.hasPrefix(Self.previewFilePrefix),
                  name.hasSuffix(Self.previewFileSuffix),
                  url != keeping else {
                continue
            }

            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate
            if let modified, modified > cutoff {
                continue
            }

            try? fileManager.removeItem(at: url)
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
        var onAnchorChange: (_ anchor: ViewportAnchor) -> Void = { _ in }
        var onFindShortcut: (_ action: FindCommand.Action) -> Void = { _ in }
        var onFindResult: (_ total: Int, _ index: Int) -> Void = { _, _ in }
        var lastFindQuery: String?
        var lastFocusToken: UUID?

        private var isLoaded = false
        private var pendingScroll: ModeSwitchAnchor?
        private var pendingFindQuery: String?

        /// How long a mode-switch capture waits for the page's JavaScript
        /// before falling back to the cached anchor.
        private static let captureTimeout: TimeInterval = 0.25
        private var pendingCaptureID = 0
        private var pendingCaptureCompletion: ((ViewportAnchor?) -> Void)?
        private var captureTimeoutWorkItem: DispatchWorkItem?

        /// Asks the live page for a fresh viewport anchor, completing with
        /// `nil` after a short timeout so a switch is never blocked by a page
        /// that is still loading or running heavy engine scripts.
        func captureAnchor(in webView: WKWebView, completion: @escaping (ViewportAnchor?) -> Void) {
            // A newer capture supersedes any still-pending one.
            pendingCaptureID += 1
            let captureID = pendingCaptureID
            pendingCaptureCompletion?(nil)
            pendingCaptureCompletion = completion

            let timeout = DispatchWorkItem { [weak self] in
                self?.finishCapture(captureID, with: nil)
            }
            captureTimeoutWorkItem?.cancel()
            captureTimeoutWorkItem = timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.captureTimeout, execute: timeout)

            webView.evaluateJavaScript(
                "window.__md2CaptureAnchor ? window.__md2CaptureAnchor() : null;"
            ) { [weak self] result, _ in
                let anchor = (result as? [String: Any]).map(Self.viewportAnchor(fromMessage:))
                self?.finishCapture(captureID, with: anchor)
            }
        }

        private func finishCapture(_ captureID: Int, with anchor: ViewportAnchor?) {
            guard captureID == pendingCaptureID,
                  let completion = pendingCaptureCompletion else { return }
            pendingCaptureCompletion = nil
            captureTimeoutWorkItem?.cancel()
            captureTimeoutWorkItem = nil
            completion(anchor)
        }

        /// Decodes the anchor payload produced by the page's `captureAnchor()`
        /// JavaScript. Missing/null fields collapse to the fallbacks-only
        /// anchor; the `ViewportAnchor` initializer sanitizes the numbers.
        static func viewportAnchor(fromMessage body: [String: Any]) -> ViewportAnchor {
            ViewportAnchor(
                sourceLine: (body["line"] as? NSNumber)?.intValue,
                sourceEndLine: (body["endLine"] as? NSNumber)?.intValue,
                intraBlockProgress: (body["progress"] as? NSNumber)?.doubleValue ?? 0,
                viewportTopInset: (body["inset"] as? NSNumber)?.doubleValue ?? 0,
                scrollFraction: (body["fraction"] as? NSNumber)?.doubleValue ?? 0,
                fallbackHeadingID: body["id"] as? String
            )
        }

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
                onAnchorChange(Self.viewportAnchor(fromMessage: body))
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
            case let .viewport(viewport):
                webView.evaluateJavaScript(
                    "window.__md2ScrollToViewportAnchor(\(Self.viewportAnchorJS(viewport)));"
                )
            case let .heading(id):
                let escapedID = MarkdownPreviewView.escapeForJS(id)
                webView.evaluateJavaScript("window.__md2ScrollToHeading('\(escapedID)');")
            case let .fraction(value):
                let clamped = min(max(value, 0), 1)
                webView.evaluateJavaScript("window.__md2ScrollToFraction(\(clamped));")
            }
        }

        /// Encodes a viewport anchor as the JSON object literal consumed by
        /// `__md2ScrollToViewportAnchor`. JSON encoding also escapes the
        /// heading id safely for the JavaScript context.
        private static func viewportAnchorJS(_ anchor: ViewportAnchor) -> String {
            var payload: [String: Any] = [
                "progress": anchor.intraBlockProgress,
                "inset": anchor.viewportTopInset,
                "fraction": anchor.scrollFraction
            ]
            if let line = anchor.sourceLine { payload["line"] = line }
            if let endLine = anchor.sourceEndLine { payload["endLine"] = endLine }
            if let headingID = anchor.fallbackHeadingID { payload["headingId"] = headingID }

            guard let data = try? JSONSerialization.data(withJSONObject: payload),
                  let json = String(data: data, encoding: .utf8) else {
                return "{}"
            }
            return json
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
        onFindAction?(.fromFindMenuItem(sender))
    }

    override func performTextFinderAction(_ sender: Any?) {
        onFindAction?(.fromFindMenuItem(sender))
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
}
