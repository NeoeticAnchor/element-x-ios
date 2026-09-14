// Copyright 2026 NeoeticAnchor.
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import Compound
import SwiftUI
import WebKit

struct IrisHTMLCardView: View {
    let card: IrisHTMLCard
    var collapsed: Binding<Bool>?
    @State private var locallyCollapsed = false
    @State private var contentSize = CGSize(width: 0, height: 80)
    @State private var viewport = CGSize(width: 300, height: 480)
    @State private var failed = false
    @State private var showingFullContent = false
    
    private var layout: IrisHTMLPreviewLayout {
        .init(contentSize: contentSize, viewport: viewport)
    }
    
    private var isCollapsed: Binding<Bool> {
        collapsed ?? $locallyCollapsed
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isCollapsed.wrappedValue {
                Text(card.summary)
                    .font(.compound.bodyMD)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 2)
                    .accessibilityIdentifier("irisHTMLSummary")
            } else if failed {
                Text(UntranslatedL10n.irisHtmlRenderFailed)
                Text(card.summary)
            } else {
                IrisHTMLWebView(document: card.document, contentSize: $contentSize, viewport: $viewport, failed: $failed)
                    .frame(height: layout.height)
                    .clipped()
                    .accessibilityIdentifier("irisHTMLInlinePreview")
            }
            HStack(spacing: 12) {
                Button {
                    isCollapsed.wrappedValue.toggle()
                } label: {
                    HStack(spacing: 4) {
                        CompoundIcon(isCollapsed.wrappedValue ? \.chevronDown : \.chevronUp,
                                     size: .custom(12), relativeTo: .footnote)
                            .accessibilityHidden(true)
                        Text(isCollapsed.wrappedValue ? UntranslatedL10n.irisHtmlExpand : UntranslatedL10n.irisHtmlCollapse)
                    }
                    .padding(.horizontal, 4)
                    .frame(minHeight: IrisHTMLPreviewLayout.footerHeight)
                    .contentShape(Rectangle())
                }
                .accessibilityIdentifier("irisHTMLToggleCollapse")
                Spacer(minLength: 0)
                if isCollapsed.wrappedValue || layout.overflows {
                    Button { showingFullContent = true } label: {
                        HStack(spacing: 4) {
                            Text(UntranslatedL10n.irisHtmlViewFullContent)
                            CompoundIcon(\.chevronRight, size: .custom(12), relativeTo: .footnote)
                                .accessibilityHidden(true)
                        }
                        .padding(.horizontal, 4)
                        .frame(minHeight: IrisHTMLPreviewLayout.footerHeight)
                        .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("irisHTMLViewFullContent")
                }
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(Color.compound.textSecondary)
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fullScreenCover(isPresented: $showingFullContent) {
            IrisHTMLBrowser(card: card)
        }
        .onChange(of: card) { _, _ in
            failed = false
            contentSize = .init(width: 0, height: 80)
        }
    }
}

struct IrisHTMLPreviewLayout {
    static let footerHeight: CGFloat = 44
    static let messageChromeHeight: CGFloat = 60
    let contentSize: CGSize
    let viewport: CGSize
    
    // Reserve room for the full-content button, sender and timestamp.
    var maximumHeight: CGFloat {
        max(80, viewport.height - Self.footerHeight - Self.messageChromeHeight)
    }
    
    var height: CGFloat {
        min(maximumHeight, max(80, contentSize.height))
    }
    
    var overflows: Bool {
        contentSize.height > maximumHeight + 1 || contentSize.width > viewport.width + 1
    }
}

private struct IrisHTMLBrowser: View {
    @Environment(\.dismiss) private var dismiss
    let card: IrisHTMLCard
    @State private var contentSize = CGSize.zero
    @State private var viewport = CGSize.zero
    @State private var failed = false
    
    var body: some View {
        ElementNavigationStack {
            Group {
                if failed {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(UntranslatedL10n.irisHtmlRenderFailed)
                            Text(card.summary)
                        }
                        .padding()
                    }
                } else {
                    IrisHTMLWebView(document: card.document, allowsScrolling: true,
                                    contentSize: $contentSize, viewport: $viewport, failed: $failed)
                        .accessibilityIdentifier("irisHTMLBrowser")
                }
            }
            .navigationTitle(UntranslatedL10n.irisHtmlFullContent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.actionDone) { dismiss() }
                        .accessibilityIdentifier("irisHTMLBrowserClose")
                }
            }
        }
    }
}

struct IrisHTMLWebView: UIViewRepresentable {
    let document: String
    var allowsScrolling = false
    @Binding var contentSize: CGSize
    @Binding var viewport: CGSize
    @Binding var failed: Bool
    
    static func configuration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.dataDetectorTypes = []
        return configuration
    }
    
    static func makeWebView(allowsScrolling: Bool) -> IrisHTMLViewportWebView {
        let view = IrisHTMLViewportWebView(frame: .zero, configuration: configuration())
        view.isOpaque = false
        view.backgroundColor = .clear
        view.scrollView.backgroundColor = .clear
        view.scrollView.isScrollEnabled = allowsScrolling
        view.scrollView.bounces = allowsScrolling
        view.scrollView.showsVerticalScrollIndicator = allowsScrolling
        view.scrollView.showsHorizontalScrollIndicator = allowsScrolling
        // Like an image, inline HTML must pass all gestures to the surrounding timeline.
        // This also prevents nested CSS scroll containers from intercepting touches.
        view.isUserInteractionEnabled = allowsScrolling
        view.allowsLinkPreview = false
        return view
    }
    
    static func load(_ document: String, in view: WKWebView) async {
        await view.configuration.websiteDataStore.httpCookieStore.setCookiePolicy(.disallow)
        guard !Task.isCancelled else { return }
        view.loadHTMLString(document, baseURL: nil)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(contentSize: $contentSize, viewport: $viewport, failed: $failed)
    }
    
    func makeUIView(context: Context) -> IrisHTMLViewportWebView {
        let view = Self.makeWebView(allowsScrolling: allowsScrolling)
        let coordinator = context.coordinator
        view.navigationDelegate = coordinator
        view.viewportChanged = { [weak coordinator] size in
            Task { @MainActor in
                guard let coordinator else { return }
                if abs(coordinator.viewport.wrappedValue.width - size.width) > 1 {
                    coordinator.contentSize.wrappedValue = .init(width: 0, height: 80)
                }
                coordinator.viewport.wrappedValue = size
            }
        }
        coordinator.observation = view.scrollView.observe(\.contentSize, options: [.new]) { [weak coordinator] _, change in
            guard let size = change.newValue, size.width.isFinite, size.height.isFinite else { return }
            Task { @MainActor in
                guard let coordinator, coordinator.contentSize.wrappedValue != size else { return }
                coordinator.contentSize.wrappedValue = size
            }
        }
        return view
    }
    
    func updateUIView(_ view: IrisHTMLViewportWebView, context: Context) {
        guard context.coordinator.document != document else { return }
        context.coordinator.document = document
        context.coordinator.loadTask?.cancel()
        context.coordinator.loadTask = Task { await Self.load(document, in: view) }
    }
    
    static func dismantleUIView(_ view: IrisHTMLViewportWebView, coordinator: Coordinator) {
        coordinator.loadTask?.cancel()
        view.navigationDelegate = nil
        view.stopLoading()
        view.viewportChanged = nil
        coordinator.observation?.invalidate()
    }
    
    final class Coordinator: NSObject, WKNavigationDelegate {
        var document: String?
        var observation: NSKeyValueObservation?
        var loadTask: Task<Void, Never>?
        let contentSize: Binding<CGSize>
        let viewport: Binding<CGSize>
        let failed: Binding<Bool>
        
        init(contentSize: Binding<CGSize>, viewport: Binding<CGSize>, failed: Binding<Bool>) {
            self.contentSize = contentSize
            self.viewport = viewport
            self.failed = failed
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled {
                failed.wrappedValue = true
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled {
                failed.wrappedValue = true
            }
        }
        
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            failed.wrappedValue = true
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            navigationAction.navigationType == .other && navigationAction.request.url?.absoluteString == "about:blank" ? .allow : .cancel
        }
    }
}

final class IrisHTMLViewportWebView: WKWebView {
    var viewportChanged: ((CGSize) -> Void)?
    private var lastViewport = CGSize.zero
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let window, bounds.width > 0 else { return }
        var availableHeight = window.safeAreaLayoutGuide.layoutFrame.height
        var ancestor = superview
        while let view = ancestor {
            if let scrollView = view as? UIScrollView {
                let visibleHeight = scrollView.bounds.height - scrollView.adjustedContentInset.top - scrollView.adjustedContentInset.bottom
                if visibleHeight > 80 {
                    availableHeight = min(availableHeight, visibleHeight)
                }
                break
            }
            ancestor = view.superview
        }
        let size = CGSize(width: bounds.width, height: max(80, availableHeight))
        guard size != lastViewport else { return }
        lastViewport = size
        viewportChanged?(size)
    }
}
