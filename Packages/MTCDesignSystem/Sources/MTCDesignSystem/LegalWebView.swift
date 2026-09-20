import SwiftUI
import WebKit

/// Shared WebView screen for legal pages (Terms, Privacy) — reused by both Settings and Premium
/// so both entry points land on the exact same in-app content instead of duplicating a loader.
/// Shows a retry state on load failure rather than a blank screen, the idiomatic-iOS equivalent
/// of Android's WebViewWithOffline.
public struct LegalWebView: View {
    private let url: URL
    @State private var loadFailed = false
    @State private var isLoading = true
    @State private var reloadToken = UUID()

    public init(url: URL) {
        self.url = url
    }

    public var body: some View {
        if loadFailed {
            offlineState
        } else {
            // A remote page can take seconds on a cold start; without this the screen is a blank
            // rectangle under the title and looks broken.
            ZStack {
                WebViewRepresentable(
                    url: url,
                    onLoadFailed: {
                        isLoading = false
                        loadFailed = true
                    },
                    onLoadFinished: { isLoading = false }
                )
                if isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .accessibilityLabel("Cargando")
                }
            }
            .id(reloadToken)
        }
    }

    private var offlineState: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Sin conexión a internet")
                .font(MTCTypography.headline)
            Text("Verifica tu conexión e intenta de nuevo")
                .font(MTCTypography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Reintentar") {
                loadFailed = false
                isLoading = true
                reloadToken = UUID()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WebViewRepresentable: UIViewRepresentable {
    let url: URL
    let onLoadFailed: () -> Void
    let onLoadFinished: () -> Void

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoadFailed: onLoadFailed, onLoadFinished: onLoadFinished)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private let onLoadFailed: () -> Void
        private let onLoadFinished: () -> Void

        init(onLoadFailed: @escaping () -> Void, onLoadFinished: @escaping () -> Void) {
            self.onLoadFailed = onLoadFailed
            self.onLoadFinished = onLoadFinished
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onLoadFinished()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onLoadFailed()
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            onLoadFailed()
        }
    }
}

#Preview("Legal WebView") {
    LegalWebView(url: URL(string: "https://gonzalo-lozg.me/apps-docs/mtcquiz/term/")!)
}
