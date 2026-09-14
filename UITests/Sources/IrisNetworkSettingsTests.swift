// Copyright 2026 NeoeticAnchor.
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import XCTest

@MainActor
final class IrisNetworkSettingsTests: XCTestCase {
    func testDisableAllClearsOptionalServiceToggles() {
        let app = XCUIApplication()
        app.launchEnvironment["UI_TESTS_SCREEN"] = "irisNetworkSettings"
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let analytics = app.switches["Usage analytics"].firstMatch
        let reports = app.switches["Crash and bug reports"].firstMatch
        XCTAssertTrue(analytics.waitForExistence(timeout: 10))
        XCTAssertEqual(analytics.value as? String, "0")
        // Compound combines the row for accessibility; the control is on its trailing edge.
        analytics.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        reports.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(analytics.value as? String, "1")
        app.buttons["Disable all optional connections"].firstMatch.tap()
        XCTAssertEqual(analytics.value as? String, "0")
        XCTAssertEqual(reports.value as? String, "0")
    }
}
