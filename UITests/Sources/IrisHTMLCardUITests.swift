// Copyright 2026 NeoeticAnchor.
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import XCTest

@MainActor
final class IrisHTMLCardUITests: XCTestCase {
    func testInlineCardAndComposerPreview() {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TESTS_SCREEN"] = "irisHTMLRoom"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(app.webViews.staticTexts["Iris report"].waitForExistence(timeout: 10))
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
