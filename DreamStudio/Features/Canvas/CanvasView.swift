import SwiftUI
import WebKit
import ComposableArchitecture

// MARK: - Canvas View

struct CanvasView: View {
    @Bindable var store: StoreOf<CanvasFeature>

    var body: some View {
        ZStack {
            if store.assembledHTML.isEmpty {
                emptyState
            } else {
                DreamWebView(
                    html: store.assembledHTML,
                    onLoaded: { store.send(.webViewLoaded) },
                    onError: { store.send(.webViewFailed($0)) }
                )
                .ignoresSafeArea(edges: store.isFullScreen ? .all : [])

                if store.isLoading {
                    loadingOverlay
                }
            }

            if let error = store.error {
                errorOverlay(error)
            }
        }
        .navigationTitle(store.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    store.send(.toggleFullScreen)
                } label: {
                    Image(systemName: store.isFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                }
            }
        }
        .onAppear {
            store.send(.onAppear)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No content to display")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Generate a dream to see the result here.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
        }
    }

    private func errorOverlay(_ error: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundStyle(.orange)
            Text("Rendering Error")
                .font(.headline)
            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding()
    }
}

// MARK: - WKWebView Wrapper

struct DreamWebView: UIViewRepresentable {
    let html: String
    var onLoaded: (() -> Void)?
    var onError: ((String) -> Void)?

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // Allow data URIs and external resources
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        config.defaultWebpagePreferences = preferences

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.bounces = true
        webView.isOpaque = false
        webView.backgroundColor = .clear

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only reload if HTML has changed
        if context.coordinator.lastHTML != html {
            context.coordinator.lastHTML = html
            webView.loadHTMLString(html, baseURL: URL(string: "https://dream.local"))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoaded: onLoaded, onError: onError)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var lastHTML: String = ""
        let onLoaded: (() -> Void)?
        let onError: ((String) -> Void)?

        init(onLoaded: (() -> Void)?, onError: ((String) -> Void)?) {
            self.onLoaded = onLoaded
            self.onError = onError
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onLoaded?()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onError?(error.localizedDescription)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            onError?(error.localizedDescription)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // Allow navigation to data URIs and local content
            if let url = navigationAction.request.url {
                if url.scheme == "data" || url.host == "dream.local" || url.host == "cdn.tailwindcss.com" {
                    decisionHandler(.allow)
                    return
                }
                // Allow CDN resources
                if url.scheme == "https" {
                    decisionHandler(.allow)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
}
