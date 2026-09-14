//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

#if IS_MAIN_APP
import EmbeddedElementCall
#endif

import Combine
import Foundation
import Macros
import SwiftUI

/// Common settings between app and NSE
nonisolated protocol CommonSettingsProtocol: AnyObject, Sendable {
    var allowSystemSuggestions: Bool { get }
    
    var lastNotificationBootTime: TimeInterval? { get set }
    var selectedNotificationTone: NotificationTone? { get set }
    var lastKnownBadgeCount: Int { get set }
    
    var logLevel: LogLevel { get }
    var traceLogPacks: Set<TraceLogPack> { get }
    var bugReportRageshakeURL: RemotePreference<RageshakeConfiguration> { get }
    var contentScannerURL: RemotePreference<URL?> { get }
    var forceDisableE2EE: RemotePreference<Bool> { get }
    var mapTilerConfiguration: RemotePreference<MapTilerConfiguration> { get }
    
    var enableOnlySignedDeviceIsolationMode: Bool { get }
    var threadsEnabled: Bool { get }
    var hideQuietNotificationAlerts: Bool { get }
    var roomListNotificationCountEnabled: Bool { get }
}

nonisolated enum AppBuildType {
    case debug
    case nightly
    case release
    
    static var current: AppBuildType {
        #if DEBUG
        return .debug
        #else
        if InfoPlistReader.main.isNightlyBuild {
            .nightly
        } else {
            .release
        }
        #endif
    }
}

/// Store Element specific app settings.
///
/// State is persisted in `UserDefaults`, which is thread-safe per Apple's documentation, hence `@unchecked`.
final nonisolated class AppSettings: @unchecked Sendable {
    static let suiteName: String = InfoPlistReader.main.appGroupIdentifier
    
    /// UserDefaults to be used on reads and writes.
    private let store: UserDefaultsProtocol
    
    static var appBuildType: AppBuildType {
        AppBuildType.current
    }
    
    func resetAllSettings() {
        MXLog.warning("Resetting the AppSettings.")
        store.reset()
        irisNetwork = IrisNetworkConfiguration()
        applyIrisNetwork()
    }
    
    func resetSessionSpecificSettings() {
        MXLog.warning("Resetting the user session specific AppSettings.")
        resetHasRunIdentityConfirmationOnboarding()
    }
    
    // MARK: - Hooks
    
    // swiftlint:disable:next function_parameter_count
    func override(accountProviders: [String],
                  allowOtherAccountProviders: Bool,
                  hideBrandChrome: Bool,
                  pushGatewayBaseURL: URL,
                  oAuthRedirectURL: URL,
                  oAuthClientURIPath: String?,
                  websiteURL: URL,
                  logoURL: URL,
                  copyrightURL: URL,
                  acceptableUseURL: URL,
                  privacyURL: URL,
                  encryptionURL: URL,
                  deviceVerificationURL: URL,
                  chatBackupDetailsURL: URL,
                  identityPinningViolationDetailsURL: URL,
                  historySharingDetailsURL: URL,
                  elementWebHosts: [String],
                  accountProvisioningHost: String,
                  bugReportApplicationID: String,
                  analyticsTermsURL: URL?,
                  mapTilerConfiguration: MapTilerConfiguration) {
        self.accountProviders = accountProviders
        self.allowOtherAccountProviders = allowOtherAccountProviders
        self.hideBrandChrome = hideBrandChrome
        self.pushGatewayBaseURL = pushGatewayBaseURL
        self.oAuthRedirectURL = oAuthRedirectURL
        self.oAuthClientURIPath = oAuthClientURIPath
        self.websiteURL = websiteURL
        self.logoURL = logoURL
        self.copyrightURL = copyrightURL
        self.acceptableUseURL = acceptableUseURL
        self.privacyURL = privacyURL
        self.encryptionURL = encryptionURL
        self.deviceVerificationURL = deviceVerificationURL
        self.chatBackupDetailsURL = chatBackupDetailsURL
        self.identityPinningViolationDetailsURL = identityPinningViolationDetailsURL
        self.historySharingDetailsURL = historySharingDetailsURL
        self.elementWebHosts = elementWebHosts
        self.accountProvisioningHost = accountProvisioningHost
        self.bugReportApplicationID = bugReportApplicationID
        self.analyticsTermsURL = analyticsTermsURL
        self.mapTilerConfiguration = RemotePreference(mapTilerConfiguration, allowsRemoteConfiguration: false)
        applyIrisNetwork()
    }
    
    // MARK: - Application
    
    /// The last known version of the app that was launched on this device, which is
    /// used to detect when migrations should be run. When `nil` the app may have been
    /// deleted between runs so should clear data in the shared container and keychain.
    @UserPreference
    var lastVersionLaunched: String?
    
    /// The Set of room identifiers of invites that the user already saw in the invites list.
    /// This Set is being used to implement badges for unread invites.
    @UserPreference(defaultValue: Set<String>())
    var seenInvites: Set<String>
    
    /// Defaults to `true` for new users, and we use a migration to set it to `false` for existing users.
    @UserPreference(defaultValue: true)
    var hasSeenNewSoundBanner: Bool
    
    /// The initial set of account providers shown to the user in the authentication flow.
    ///
    /// Account provider is the friendly term for the server name. It should not contain an `https` prefix and should
    /// match the last part of the user ID. For example `example.com` and not `https://matrix.example.com`.
    private(set) var accountProviders = ["hermes.irisr.art"]
    /// Whether or not the user is allowed to manually enter their own account provider or must select from one of `defaultAccountProviders`.
    private(set) var allowOtherAccountProviders = false
    /// Whether the components surrounding the app brand/logo should be hidden or not
    private(set) var hideBrandChrome = false
    
    /// The task identifier used for background app refresh. Also used in main target's the Info.plist
    let backgroundAppRefreshTaskIdentifier = "io.element.elementx.background.refresh"
    
    /// A URL where users can go read more about the app.
    private(set) var websiteURL: URL = "https://hermes.irisr.art"
    /// A URL that contains the app's logo that may be used when showing content in a web view.
    private(set) var logoURL: URL = "https://hermes.irisr.art/mobile-icon.png"
    /// A URL that contains that app's copyright notice.
    private(set) var copyrightURL: URL = "https://hermes.irisr.art/copyright"
    /// A URL that contains the app's Terms of use.
    private(set) var acceptableUseURL: URL = "https://hermes.irisr.art/acceptable-use-policy-terms"
    /// A URL that contains the app's Privacy Policy.
    private(set) var privacyURL: URL = "https://hermes.irisr.art/privacy"
    /// A URL where users can go read more about encryption in general.
    private(set) var encryptionURL: URL = "https://hermes.irisr.art/help#encryption"
    /// A URL where users can go read more about device verification..
    private(set) var deviceVerificationURL: URL = "https://hermes.irisr.art/help#encryption-device-verification"
    /// A URL where users can go read more about the chat backup.
    private(set) var chatBackupDetailsURL: URL = "https://hermes.irisr.art/help#encryption5"
    /// A URL where users can go read more about identity pinning violations
    private(set) var identityPinningViolationDetailsURL: URL = "https://hermes.irisr.art/help#encryption18"
    /// A URL describing how history sharing works
    private(set) var historySharingDetailsURL: URL = "https://hermes.irisr.art/en/help#e2ee-history-sharing"
    
    /// Any domains that Element web may be hosted on - used for handling links.
    private(set) var elementWebHosts = ["hermes.irisr.art"]
    /// The domain that account provisioning links will be hosted on - used for handling the links.
    private(set) var accountProvisioningHost = "hermes.irisr.art"
    /// The App Store URL for Element Pro, shown to the user when a homeserver requires that app.
    /// **Note:** This property isn't overridable as it in unexpected for forks to come across the error (or to even have a "Pro" app).
    let elementProAppStoreURL: URL = "https://apps.apple.com/app/element-pro-for-work/id6502951615"
    
    @UserPreference(defaultValue: AppAppearance.system)
    var appAppearance: AppAppearance
    
    /// Tracks previous servers the user connected to for autocompletion purposes. Entries are made lowercase on write.
    @UserPreference(key: "previousServers", defaultValue: [])
    var previousServers: [String]
    
    var defaultServer: String {
        previousServers.first ?? accountProviders[0]
    }
    
    // MARK: - Security
    
    /// The app must be locked with a PIN code as part of the authentication flow.
    let appLockIsMandatory = false
    /// The amount of time the app can remain in the background for without requesting the PIN/TouchID/FaceID.
    let appLockGracePeriod: TimeInterval = 0
    /// Any codes that the user isn't allowed to use for their PIN.
    let appLockPINCodeBlockList = ["0000", "1234"]
    /// The number of attempts the user has made to unlock the app with a PIN code (resets when unlocked).
    @UserPreference(defaultValue: 0)
    var appLockNumberOfPINAttempts: Int
    
    // MARK: - Authentication
    
    /// Any pre-defined static client registrations for OAuth issuers.
    let oAuthStaticRegistrations: [URL: String] = [:]
    /// The redirect URL used for OAuth. For the normal case we don't actually need the bundle ID as the web authentication session handles the redirect internally.
    /// However in the case where MAS sends the user to an external app, we need to make sure that the system will open the correct variant of the app (e.g. Nightly).
    private(set) nonisolated(unsafe) var oAuthRedirectURL: URL! = URL(string: "https://hermes.irisr.art/oauth/ios/\(InfoPlistReader.main.bundleIdentifier)")
    /// A path that is appended to `websiteURL` to form the OAuth `clientURI`. MAS uses `clientURI` as the identifier for a specific app, allowing us to
    /// distinguish the various clients we have for Android, iOS and Web from each other.
    /// Intentionally a distinct property so it can be easily overridden without having to manipulate the website URL.
    private(set) var oAuthClientURIPath: String? = "apps/ios"
    
    var oAuthConfiguration: OAuthConfiguration {
        OAuthConfiguration(clientName: InfoPlistReader.main.bundleDisplayName,
                           redirectURI: oAuthRedirectURL,
                           clientURI: oAuthClientURIPath.map { websiteURL.appending(path: $0) } ?? websiteURL,
                           logoURI: logoURL,
                           tosURI: acceptableUseURL,
                           policyURI: privacyURL,
                           staticRegistrations: oAuthStaticRegistrations.mapKeys { $0.absoluteString })
    }
    
    /// Whether or not the Create Account button is shown on the start screen.
    ///
    /// **Note:** Setting this to false doesn't prevent someone from creating an account when the selected homeserver's MAS allows registration.
    let showCreateAccountButton = true
    
    // MARK: - Notifications
    
    var pusherAppID: String {
        #if DEBUG
        InfoPlistReader.main.baseBundleIdentifier + ".ios.dev"
        #else
        InfoPlistReader.main.baseBundleIdentifier + ".ios.prod"
        #endif
    }
    
    private(set) var pushGatewayBaseURL: URL = "https://hermes.irisr.art"
    var pushGatewayNotifyEndpoint: URL {
        (irisNetwork.endpoint(irisNetwork.pushGatewayURL, enabled: irisNetwork.pushEnabled) ?? pushGatewayBaseURL).appending(path: "_matrix/push/v1/notify")
    }
    
    @UserPreference(defaultValue: false)
    var enableNotifications: Bool
    
    @UserPreference(defaultValue: true)
    var enableInAppNotifications: Bool
    
    @UserPreference(defaultValue: false)
    var hideQuietNotificationAlerts: Bool
    
    /// Tag describing which set of device specific rules a pusher executes.
    @UserPreference
    var pusherProfileTag: String?
    
    /// The device's last boot time as recorded by the NSE.
    @UserPreference
    var lastNotificationBootTime: TimeInterval?
    
    /// The app icon badge value the app last computed from the SDK's unread notification counts.
    @UserPreference(defaultValue: 0)
    var lastKnownBadgeCount: Int
    
    /// The sound played when delivering noisy notifications. If nil, use the ElementX default
    @UserPreference
    var selectedNotificationTone: NotificationTone?
    
    // MARK: - Logging
    
    @UserPreference(defaultValue: LogLevel.info)
    var logLevel: LogLevel
    
    @UserPreference(defaultValue: Set<TraceLogPack>())
    var traceLogPacks: Set<TraceLogPack>
    
    // MARK: - Bug report
    
    let bugReportRageshakeURL = RemotePreference<RageshakeConfiguration>(.disabled, allowsRemoteConfiguration: false)
    var bugReportSentryURL: URL? {
        irisNetwork.endpoint(irisNetwork.sentryDSN, enabled: irisNetwork.reportsEnabled, isSentryDSN: true)
    }
    
    // Rust crash transport has no per-session stop mechanism; retain local traces for explicit bug reports.
    let bugReportSentryRustURL: URL? = nil
    /// The name allocated by the bug report server
    private(set) var bugReportApplicationID = "element-x-ios"
    
    // MARK: - Content scanner
    
    /// The base URL of the content scanner server used to scan media before it is downloaded.
    /// `nil` when content scanning is disabled.
    let contentScannerURL = RemotePreference<URL?>(nil, allowsRemoteConfiguration: false)
    
    // MARK: - Encryption
    
    /// Whether the server forbids the use of E2EE: new rooms are created unencrypted and
    /// enabling encryption on existing rooms is not offered.
    let forceDisableE2EE: RemotePreference<Bool> = .init(false)
    
    // MARK: - Analytics
    
    /// The configuration to use for analytics. Set to `nil` to disable analytics.
    var analyticsConfiguration: AnalyticsConfiguration? {
        guard let host = irisNetwork.endpoint(irisNetwork.analyticsHost, enabled: irisNetwork.analyticsEnabled),
              !irisNetwork.analyticsKey.isEmpty else { return nil }
        return AnalyticsConfiguration(host: host.absoluteString, apiKey: irisNetwork.analyticsKey)
    }
    
    /// The URL to open with more information about analytics terms. When this is `nil` the "Learn more" link will be hidden.
    private(set) var analyticsTermsURL: URL? = "https://hermes.irisr.art/cookie-policy"
    /// Whether or not there the app is able ask for user consent to enable analytics or sentry reporting.
    var canPromptForAnalytics: Bool {
        analyticsConfiguration != nil || bugReportSentryURL != nil
    }
    
    /// Whether the user has opted in to send analytics.
    @UserPreference(defaultValue: AnalyticsConsentState.unknown)
    var analyticsConsentState: AnalyticsConsentState
    
    /// Whether a user session has ever been set up on this device. Deliberately not cleared on
    /// logout: it stops the Classic app migration prompt from reappearing when an Element X
    /// user is signed out unexpectedly (invalidated token, corrupted storage, etc).
    @UserPreference(defaultValue: false)
    var hasSignedInBefore: Bool
    
    @UserPreference(defaultValue: false)
    var hasRunNotificationPermissionsOnboarding: Bool
    
    @UserPreference(defaultValue: false)
    var hasRunIdentityConfirmationOnboarding: Bool
    
    @UserPreference(defaultValue: false)
    var hasRequestedLocationAlwaysLocationAuthorization: Bool
    
    @UserPreference(defaultValue: [FrequentlyUsedEmoji]())
    var frequentlyUsedSystemEmojis: [FrequentlyUsedEmoji]
    
    // MARK: - Live Location
    
    @UserPreference(key: "liveLocationSharingTimeoutDatesByRoomID", defaultValue: [String: LiveLocationSession]())
    var liveLocationSharingSessionsByRoomID: [String: LiveLocationSession]
    
    @UserPreference(defaultValue: 10)
    var liveLocationMinimumDistanceUpdate: Int
    
    @UserPreference(defaultValue: false)
    var liveLocationDisclaimerDisplayed: Bool
    
    // MARK: - Home Screen
    
    @UserPreference(defaultValue: RoomListActivityVisibility.current)
    var roomListActivityVisibility: RoomListActivityVisibility
    
    @UserPreference(defaultValue: false)
    var roomListNotificationCountEnabled: Bool
    
    // MARK: - Room Screen
    
    @UserPreference(defaultValue: AppBuildType.current == .debug)
    var viewSourceEnabled: Bool
    
    @UserPreference(defaultValue: true)
    var optimizeMediaUploads: Bool
    
    @UserPreference(defaultValue: AudioPlaybackSpeed.default)
    var voiceMessagePlaybackSpeed: AudioPlaybackSpeed
    
    /// Whether or not to show a warning on the media caption composer so the user knows
    /// that captions might not be visible to users who are using other Matrix clients.
    let shouldShowMediaCaptionWarning = true
    
    // MARK: - Element Call
    
    #if IS_MAIN_APP
    // swiftlint:disable:next force_unwrapping
    let elementCallBaseURL: URL = EmbeddedElementCall.appURL!
    #endif
    
    var elementCallPosthogAPIHost: String {
        irisNetwork.analyticsHost
    }
    
    var elementCallPosthogAPIKey: String {
        irisNetwork.analyticsKey
    }
    
    var elementCallPosthogSentryDSN: String {
        irisNetwork.reportsEnabled ? irisNetwork.sentryDSN : ""
    }
    
    var elementCallBaseURLOverride: URL? {
        get { irisNetwork.endpoint(irisNetwork.callURL, enabled: irisNetwork.callsEnabled) }
        set { var value = irisNetwork; value.callURL = newValue?.absoluteString ?? ""; irisNetwork = value }
    }
    
    // MARK: - Users
    
    /// Whether to hide the display name and avatar of ignored users as these may contain objectionable content.
    let hideIgnoredUserProfiles = true
    
    // MARK: - Maps
    
    /// The locally-bundled MapTiler configuration.
    static let bundledMapTilerConfiguration = MapTilerConfiguration(baseURL: "https://hermes.irisr.art",
                                                                    apiKey: nil,
                                                                    lightStyleID: "basic-v2",
                                                                    darkStyleID: "basic-v2-dark")
    private(set) var mapTilerConfiguration = RemotePreference(AppSettings.bundledMapTilerConfiguration, allowsRemoteConfiguration: false)
    
    // MARK: - Presence
    
    @UserPreference(defaultValue: true)
    var sharePresence: Bool
    
    // MARK: - Feature Flags
    
    /// Others
    @UserPreference(defaultValue: false)
    var fuzzyRoomListSearchEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var lowPriorityFilterEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var mentionsFilterEnabled: Bool
    
    /// Configuration to enable only signed device isolation mode for  crypto. In this mode only devices signed by their owner will be considered in e2ee rooms.
    @UserPreference(defaultValue: false)
    var enableOnlySignedDeviceIsolationMode: Bool
    
    @UserPreference(defaultValue: false)
    var knockingEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var threadsEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var messageMultiSelectEnabled: Bool
    
    @UserPreference(defaultValue: ProcessInfo().isiOSAppOnMac)
    var globalSearchEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var focusEventOnNotificationTap: Bool
    
    @UserPreference(defaultValue: false)
    var linkPreviewsEnabled: Bool
    
    /// Enables *sending* gallery messages (multiple media in a single message).
    /// Received galleries are always rendered regardless of this flag.
    @UserPreference(defaultValue: false)
    var galleryEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var jumpToReadMarkerEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var linkNewDeviceEnabled: Bool
    
    @UserPreference(defaultValue: false)
    var automaticBackPaginationEnabled: Bool
    
    @UserPreference(key: "clientPausingAndResumingEnabledV2", defaultValue: false, volatile: true)
    var clientPausingAndResumingEnabled: Bool
    
    @UserPreference(defaultValue: AppBuildType.current != .release)
    var developerOptionsEnabled: Bool
    
    var allowSystemSuggestions: Bool {
        irisNetwork.systemSuggestionsEnabled
    }
    
    @UserPreference
    var irisPushToken: String?
    
    @UserPreference(defaultValue: IrisNetworkConfiguration())
    var irisNetwork: IrisNetworkConfiguration
    
    func applyIrisNetwork() {
        let value = irisNetwork
        bugReportRageshakeURL.setLocalValue(value.endpoint(value.rageshakeURL, enabled: value.reportsEnabled).map(RageshakeConfiguration.url) ?? .disabled)
        contentScannerURL.setLocalValue(value.endpoint(value.scannerURL, enabled: value.scannerEnabled))
        let mapURL = value.endpoint(value.mapBaseURL, enabled: value.mapsEnabled)
        mapTilerConfiguration.setLocalValue(MapTilerConfiguration(baseURL: mapURL ?? Self.bundledMapTilerConfiguration.baseURL,
                                                                  apiKey: mapURL == nil ? nil : value.mapAPIKey,
                                                                  lightStyleID: value.mapLightStyle,
                                                                  darkStyleID: value.mapDarkStyle))
        linkPreviewsEnabled = value.linkPreviewsEnabled
        if !value.pushEnabled {
            enableNotifications = false
        }
    }
    
    init(store: UserDefaultsProtocol) {
        self.store = store
        applyIrisNetwork()
    }
    
    static func volatile() -> AppSettings {
        AppSettings(store: VolatileUserDefaults())
    }
}

nonisolated extension AppSettings: CommonSettingsProtocol { }
