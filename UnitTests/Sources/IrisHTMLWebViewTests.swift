// Copyright 2026 NeoeticAnchor.
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

@testable import ElementX
import WebKit
import XCTest

final nonisolated class IrisHTMLWebViewTests: XCTestCase {
    @MainActor
    func testDocumentCannotRunScriptsOrLoadExternalResources() async throws {
        let configuration = IrisHTMLWebView.configuration()
        let recorder = ResourceRecorder()
        configuration.setURLSchemeHandler(recorder, forURLScheme: "iris-test")
        XCTAssertFalse(configuration.defaultWebpagePreferences.allowsContentJavaScript)
        XCTAssertFalse(configuration.websiteDataStore.isPersistent)
        let view = WKWebView(frame: .init(x: 0, y: 0, width: 320, height: 240), configuration: configuration)
        let loaded = expectation(description: "Static document loaded")
        let delegate = LoadDelegate(loaded: loaded)
        view.navigationDelegate = delegate
        // Bypass the sanitizer deliberately to exercise WebKit's independent containment.
        let card = IrisHTMLCard(version: 1, html: """
        <h1>Contained</h1><script>document.body.setAttribute('data-executed','yes')</script>
        <img src="iris-test://blocked/image"><style>@import url('iris-test://blocked/css');body{background-image:url('iris-test://blocked/bg')}</style>
        <iframe src="iris-test://blocked/frame"></iframe>
        """, summary: "Contained")
        view.loadHTMLString(card.document, baseURL: nil)
        await fulfillment(of: [loaded], timeout: 15)
        let executed = try await view.evaluateJavaScript("document.body.hasAttribute('data-executed')") as? Bool
        XCTAssertEqual(executed, false)
        XCTAssertEqual(recorder.requests, 0)
        let text = try await view.evaluateJavaScript("document.querySelector('h1').textContent") as? String
        XCTAssertEqual(text, "Contained")
        view.stopLoading()
    }
    
    @MainActor
    private final class LoadDelegate: NSObject, WKNavigationDelegate {
        let loaded: XCTestExpectation
        init(loaded: XCTestExpectation) {
            self.loaded = loaded
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            loaded.fulfill()
        }
    }
    
    @MainActor
    private final class ResourceRecorder: NSObject, WKURLSchemeHandler {
        var requests = 0
        func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
            requests += 1
            urlSchemeTask.didFailWithError(URLError(.notConnectedToInternet))
        }
        
        func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) { }
    }
}
