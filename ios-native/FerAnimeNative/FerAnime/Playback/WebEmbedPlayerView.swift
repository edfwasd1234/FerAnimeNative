import SwiftUI
import WebKit

struct WebEmbedPlayerView: UIViewRepresentable {
    let url: URL
    var onPlaybackError: (() -> Void)? = nil

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.userContentController = WKUserContentController()

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.navigationDelegate = context.coordinator
        context.coordinator.installContentRules(into: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onPlaybackError = onPlaybackError
        if webView.url != url {
            context.coordinator.resetLoadState()
            webView.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onPlaybackError: (() -> Void)?
        private var reportedFailedLoad = false

        func installContentRules(into webView: WKWebView) {
            let rules = """
            [
              {"trigger":{"url-filter":".*","if-domain":["*doubleclick.net","*googlesyndication.com","*adnxs.com","*popads.net","*taboola.com","*outbrain.com"]},"action":{"type":"block"}},
              {"trigger":{"url-filter":".*(popup|banner|ads|advert).*"},"action":{"type":"block"}}
            ]
            """

            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "FerAnimeContentRules",
                encodedContentRuleList: rules
            ) { list, _ in
                guard let list else { return }
                DispatchQueue.main.async {
                    webView.configuration.userContentController.add(list)
                }
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, navigationAction.targetFrame == nil {
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if let response = navigationResponse.response as? HTTPURLResponse, response.statusCode == 410 {
                notifyPlaybackError()
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code == NSURLErrorCancelled { return }
            notifyPlaybackError()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code == NSURLErrorCancelled { return }
            notifyPlaybackError()
        }

        func resetLoadState() {
            reportedFailedLoad = false
        }

        private func notifyPlaybackError() {
            guard !reportedFailedLoad else { return }
            reportedFailedLoad = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.onPlaybackError?()
            }
        }
    }
}
