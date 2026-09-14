// Copyright 2026 NeoeticAnchor.
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import Foundation

nonisolated struct IrisNetworkConfiguration: Codable, Equatable, Sendable {
    var systemSuggestionsEnabled = false
    var analyticsEnabled = false
    var reportsEnabled = false
    var mapsEnabled = false
    var callsEnabled = false
    var scannerEnabled = false
    var externalLinksEnabled = false
    var linkPreviewsEnabled = false
    var pushEnabled = false
    var analyticsHost = ""
    var analyticsKey = ""
    var rageshakeURL = ""
    var sentryDSN = ""
    var mapBaseURL = ""
    var mapAPIKey = ""
    var mapLightStyle = "basic-v2"
    var mapDarkStyle = "basic-v2-dark"
    var callURL = ""
    var scannerURL = ""
    var pushGatewayURL = ""
    
    mutating func disableAll() {
        systemSuggestionsEnabled = false
        analyticsEnabled = false
        reportsEnabled = false
        mapsEnabled = false
        callsEnabled = false
        scannerEnabled = false
        externalLinksEnabled = false
        linkPreviewsEnabled = false
        pushEnabled = false
    }
    
    func endpoint(_ value: String, enabled: Bool, isSentryDSN: Bool = false) -> URL? {
        guard enabled, let url = URL(string: value), url.scheme == "https",
              let host = url.host, !host.isEmpty, url.password == nil,
              isSentryDSN || url.user == nil else { return nil }
        return url
    }
    
    var hasValidEndpoints: Bool {
        let endpoints = [(analyticsEnabled, analyticsHost), (reportsEnabled && !rageshakeURL.isEmpty, rageshakeURL),
                         (mapsEnabled, mapBaseURL), (callsEnabled, callURL), (scannerEnabled, scannerURL), (pushEnabled, pushGatewayURL)]
        return endpoints.allSatisfy { !$0.0 || endpoint($0.1, enabled: true) != nil }
            && (!analyticsEnabled || !analyticsKey.isEmpty)
            && (!reportsEnabled || !rageshakeURL.isEmpty || !sentryDSN.isEmpty)
            && (sentryDSN.isEmpty || endpoint(sentryDSN, enabled: true, isSentryDSN: true) != nil)
    }
}
