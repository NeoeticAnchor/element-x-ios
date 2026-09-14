// Copyright 2026 NeoeticAnchor.
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import XCTest

@MainActor
final class IrisHTMLCardUITests: XCTestCase {
    func testCollapseSummaryAndExpand() {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TESTS_SCREEN"] = "irisHTMLLongRoom"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let toggle = app.buttons["irisHTMLToggleCollapse"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        let previewWidth = app.webViews.firstMatch.frame.width
        toggle.tap()
        let summary = app.staticTexts["irisHTMLSummary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertFalse(app.webViews.firstMatch.exists)
        XCTAssertLessThan(summary.frame.height, 150)
        XCTAssertGreaterThanOrEqual(toggle.frame.minY, summary.frame.maxY)
        XCTAssertLessThan(toggle.frame.maxX, app.buttons["irisHTMLViewFullContent"].frame.minX)
        XCTAssertEqual(summary.frame.width, previewWidth, accuracy: 25)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Collapsed HTML summary"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["irisHTMLViewFullContent"].tap()
        let close = app.buttons["irisHTMLBrowserClose"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertFalse(app.webViews.firstMatch.exists)
        toggle.tap()
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(summary.exists)
    }
    
    func testLongCardOpensCookieFreeFullContent() {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TESTS_SCREEN"] = "irisHTMLLongRoom"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let button = app.buttons["irisHTMLViewFullContent"]
        XCTAssertTrue(button.waitForExistence(timeout: 15))
        let inline = app.webViews.firstMatch
        XCTAssertLessThanOrEqual(inline.frame.height, app.frame.height)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "One-screen HTML preview"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let portraitHeight = inline.frame.height
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let resized = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in inline.frame.height < portraitHeight }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [resized], timeout: 5), .completed)
        XCTAssertLessThanOrEqual(inline.frame.height, app.frame.height)
        XCUIDevice.shared.orientation = .portrait
        button.tap()
        let close = app.buttons["irisHTMLBrowserClose"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        let browser = app.webViews.firstMatch
        let end = browser.staticTexts["End of report"]
        for _ in 0..<10 where !end.isHittable {
            browser.swipeUp()
        }
        XCTAssertTrue(end.isHittable)
        let fullScreenshot = XCTAttachment(screenshot: app.screenshot())
        fullScreenshot.name = "Cookie-free full HTML reader"
        fullScreenshot.lifetime = .keepAlways
        add(fullScreenshot)
        close.tap()
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertFalse(close.exists)
    }
    
    func testInlineCardAndComposerPreview() {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TESTS_SCREEN"] = "irisHTMLRoom"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.webViews.staticTexts["Iris report"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["irisHTMLViewFullContent"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Iris inline HTML card"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons[A11yIdentifiers.roomScreen.composerToolbar.openComposeOptions].tap()
        app.buttons["irisHTMLCompose"].tap()
        let source = app.textViews["irisHTMLSource"]
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        source.tap()
        source.typeText("<h2>Preview report</h2><table><tr><td>42</td></tr></table>")
        XCTAssertFalse(app.buttons["irisHTMLSend"].isEnabled)
        app.buttons["Preview card"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Preview report"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["irisHTMLSend"].isEnabled)
    }
}
