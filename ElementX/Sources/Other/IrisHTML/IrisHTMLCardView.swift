// Copyright 2026 NeoeticAnchor.
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import SwiftUI
import WebKit

struct IrisHTMLCardView: View {
    let card: IrisHTMLCard
    @State private var height: CGFloat = 160
    @State private var failed = false
    
    var body: some View {
        Group {
            if failed {
                VStack(alignment: .leading, spacing: 8) {
                    Text(UntranslatedL10n.irisHtmlRenderFailed)
                    Text(card.summary)
                }
            } else {
                IrisHTMLWebView(document: card.document, height: $height, failed: $failed)
                    .frame(height: height)
            }
        }
        .accessibilityIdentifier("irisHTMLCard")
        .onChange(of: card) { _, _ in failed = false }
    }
}

struct IrisHTMLWebView: UIViewRepresentable {
    let document: String
    @Binding var height: CGFloat
    @Binding var failed: Bool
    
    static func configuration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.dataDetectorTypes = []
        return configuration
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(height: $height, failed: $failed)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = Self.configuration()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        view.allowsLinkPreview = false
        context.coordinator.observation = view.scrollView.observe(\.contentSize, options: [.new]) { _, change in
            guard let size = change.newValue else { return }
            Task { @MainActor in
                let height = min(1800, max(80, size.height))
                if abs(context.coordinator.height.wrappedValue - height) > 1 {
                    context.coordinator.height.wrappedValue = height
                }
            }
        }
        return view
    }
    
    func updateUIView(_ view: WKWebView, context: Context) {
        guard context.coordinator.document != document else { return }
        context.coordinator.document = document
        view.loadHTMLString(document, baseURL: nil)
    }
    
    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        view.stopLoading()
        view.navigationDelegate = nil
        coordinator.observation?.invalidate()
    }
    
    final class Coordinator: NSObject, WKNavigationDelegate {
        var document: String?
        var observation: NSKeyValueObservation?
        let height: Binding<CGFloat>
        let failed: Binding<Bool>
        
        init(height: Binding<CGFloat>, failed: Binding<Bool>) {
            self.height = height
            self.failed = failed
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            failed.wrappedValue = true
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            failed.wrappedValue = true
        }
        
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            failed.wrappedValue = true
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            // Only the locally supplied document can navigate. Static cards never open URLs.
            navigationAction.navigationType == .other && navigationAction.request.url?.absoluteString == "about:blank" ? .allow : .cancel
        }
    }
}
