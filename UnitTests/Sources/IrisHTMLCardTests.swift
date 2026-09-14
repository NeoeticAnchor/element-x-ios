// Copyright 2026 NeoeticAnchor.
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

@testable import ElementX
import Foundation
import SwiftSoup
import Testing

struct IrisHTMLCardTests {
    @Test func preservesStaticLayoutAndBuildsReadableFallback() throws {
        let card = try #require(IrisHTMLCard.prepare("<style>td{color:red}</style><h2>Report</h2><table><tr><td>Ready</td></tr></table>"))
        #expect(card.html.contains("<table>"))
        #expect(card.html.contains("color:red"))
        #expect(card.summary == "Report Ready")
        #expect(IrisHTMLCard.prepare(card.html) == card)
    }
    
    @Test func preservesBodyStylingAndCSSSelectors() throws {
        let card = try #require(IrisHTMLCard.prepare("<body class='report' style='color:red'><p id='total'>42</p></body>"))
        let document = try SwiftSoup.parse(card.document)
        #expect(try document.body()?.attr("class") == "report")
        #expect(try document.body()?.attr("style") == "color:red")
        #expect(try document.select("#total").text() == "42")
    }
    
    @Test func removesActiveContentAndNetworkAttributes() throws {
        let source = """
        <base href="https://evil.invalid"><meta http-equiv="refresh" content="0;url=https://evil.invalid">
        <h1 onclick="alert(1)">Safe</h1><script>steal()</script><iframe src="https://evil.invalid"></iframe>
        <form action="https://evil.invalid"><input value="secret"></form><svg onload="steal()"></svg>
        <a href="https://evil.invalid" ping="https://evil.invalid">Text</a>
        <img src="https://evil.invalid/pixel" srcset="https://evil.invalid/other 2x" onerror="steal()" alt="Image">
        """
        let card = try #require(IrisHTMLCard.prepare(source))
        let document = try SwiftSoup.parse(card.html)
        #expect(try document.select("script,iframe,form,svg,base,meta,a").isEmpty())
        #expect(!card.html.contains("evil.invalid"))
        #expect(!card.html.contains("steal"))
        #expect(!card.html.contains("onclick"))
        #expect(card.summary.contains("Safe"))
    }
    
    @Test func allowsOnlyEmbeddedRasterImageSources() throws {
        let card = try #require(IrisHTMLCard.prepare("<p>Images</p><img src='data:image/png;base64,AA=='><img src='data:image/svg+xml;base64,AA=='><img src='file:///etc/passwd'>"))
        let images = try SwiftSoup.parse(card.html).select("img[src]")
        #expect(images.count == 1)
        #expect(try images.first()?.attr("src") == "data:image/png;base64,AA==")
    }
    
    @Test func roundTripsExtraContentAndUsesLatestEdit() throws {
        let card = try #require(IrisHTMLCard.prepare("<p>First</p>"))
        let edited = try #require(IrisHTMLCard.prepare("<p>Edited</p>"))
        #expect(try IrisHTMLCard.fromEventJSON("{\"content\":\(card.extraContentJSON())}") == card)
        #expect(try IrisHTMLCard.fromEventJSON("{\"content\":{\"m.new_content\":\(edited.extraContentJSON())}}") == edited)
        #expect(IrisHTMLCard.fromEventJSON("{\"content\":{\"body\":\"plain\"}}") == nil)
        let future = IrisHTMLCard(version: 2, html: card.html, summary: card.summary)
        #expect(try IrisHTMLCard.fromEventJSON("{\"content\":\(future.extraContentJSON())}") == nil)
    }
    
    @Test func rejectsEmptyAndOversizedDocuments() {
        #expect(IrisHTMLCard.prepare("<script>run()</script>") == nil)
        #expect(IrisHTMLCard.prepare(String(repeating: "x", count: IrisHTMLCard.maximumBytes + 1)) == nil)
        #expect(IrisHTMLCard.fromEventJSON(nil) == nil)
    }
}
