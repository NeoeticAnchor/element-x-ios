// Copyright 2026 NeoeticAnchor.
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

@testable import ElementX
import Testing

struct IrisNetworkConfigurationTests {
    @Test func defaultsDoNotEnableOutboundServices() {
        let settings = AppSettings.volatile()
        #expect(settings.analyticsConfiguration == nil)
        #expect(settings.bugReportSentryURL == nil)
        #expect(settings.bugReportSentryRustURL == nil)
        #expect(settings.bugReportRageshakeURL.publisher.value == .disabled)
        #expect(!settings.mapTilerConfiguration.publisher.value.isEnabled)
        #expect(settings.elementCallBaseURLOverride == nil)
        #expect(!settings.enableNotifications)
        #expect(!settings.irisNetwork.pushEnabled)
        #expect(!settings.canPromptForAnalytics)
        #expect(!settings.allowSystemSuggestions)
        settings.analyticsConsentState = .optedIn
        #expect(settings.analyticsConfiguration == nil)
    }
    
    @Test func rejectMissingAndUnsafeEndpoints() {
        var configuration = IrisNetworkConfiguration()
        configuration.callsEnabled = true
        for value in ["", "http://iris.example", "file:///tmp/call", "https://user:password@iris.example"] {
            configuration.callURL = value
            #expect(!configuration.hasValidEndpoints)
        }
        configuration.callURL = "https://call.iris.example/custom"
        #expect(configuration.hasValidEndpoints)
    }
    
    @Test func localConfigurationWinsOverRemoteDefaults() {
        let settings = AppSettings.volatile()
        settings.bugReportRageshakeURL.applyRemoteValue(.url("https://rageshakes.element.io/api/submit"))
        #expect(settings.bugReportRageshakeURL.publisher.value == .disabled)
        settings.mapTilerConfiguration.applyRemoteValue(.init(baseURL: "https://api.maptiler.com/maps",
                                                              apiKey: "public", lightStyleID: "light", darkStyleID: "dark"))
        #expect(!settings.mapTilerConfiguration.publisher.value.isEnabled)
    }
    
    @Test func disablingAllPreservesEndpointsButRemovesEffectiveServices() {
        let settings = AppSettings.volatile()
        var configuration = IrisNetworkConfiguration()
        configuration.mapsEnabled = true
        configuration.mapBaseURL = "https://maps.iris.example/maps"
        configuration.reportsEnabled = true
        configuration.rageshakeURL = "https://reports.iris.example/submit"
        configuration.pushEnabled = true
        configuration.pushGatewayURL = "https://push.iris.example"
        settings.irisNetwork = configuration
        settings.applyIrisNetwork()
        #expect(settings.mapTilerConfiguration.publisher.value.isEnabled)
        #expect(settings.bugReportRageshakeURL.publisher.value == .url("https://reports.iris.example/submit"))
        settings.enableNotifications = true
        configuration.disableAll()
        settings.irisNetwork = configuration
        settings.applyIrisNetwork()
        #expect(!settings.mapTilerConfiguration.publisher.value.isEnabled)
        #expect(settings.bugReportRageshakeURL.publisher.value == .disabled)
        #expect(!settings.enableNotifications)
        #expect(settings.irisNetwork.mapBaseURL == "https://maps.iris.example/maps")
    }
    
    @Test func disabledLinkPreviewNeverLoadsMetadata() async {
        let provider = LinkMetadataProvider(appSettings: .volatile())
        let result = await provider.fetchMetadataFor(url: "https://unreachable.invalid")
        guard case .success(let item) = result else {
            Issue.record("Disabled previews should return an empty result without a network request")
            return
        }
        #expect(item.metadata == nil)
        #expect(provider.metadataItems.isEmpty)
    }
}
