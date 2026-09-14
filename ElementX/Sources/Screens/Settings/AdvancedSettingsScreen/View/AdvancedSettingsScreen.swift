//
// Copyright 2025 Element Creations Ltd.
// Copyright 2022-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial
// Please see LICENSE files in the repository root for full details.
//

import Compound
import SwiftUI

struct AdvancedSettingsScreen: View {
    static let measurementFormatter = {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .providedUnit
        formatter.unitStyle = .short
        return formatter
    }()
    
    @Bindable var context: AdvancedSettingsScreenViewModel.Context
    
    var body: some View {
        Form {
            irisNetworkSection
            Section {
                ListRow(label: .plain(title: L10n.commonAppearance),
                        kind: .picker(selection: $context.appAppearance,
                                      items: AppAppearance.allCases.map { (title: $0.name, tag: $0) }))
                
                ListRow(label: .plain(title: L10n.actionViewSource,
                                      description: L10n.screenAdvancedSettingsViewSourceDescription),
                        kind: .toggle($context.viewSourceEnabled))
                
                ListRow(label: .plain(title: L10n.screenAdvancedSettingsSharePresence,
                                      description: L10n.screenAdvancedSettingsSharePresenceDescription),
                        kind: .toggle($context.sharePresence))
                
                ListRow(label: .plain(title: L10n.screenAdvancedSettingsMediaCompressionTitle,
                                      description: L10n.screenAdvancedSettingsMediaCompressionDescription),
                        kind: .toggle($context.optimizeMediaUploads))
                    .onChange(of: context.optimizeMediaUploads) {
                        context.send(viewAction: .optimizeMediaUploadsChanged)
                    }
            }
            
            moderationAndSafetySection
            timelineMediaSection
            liveLocationSection
        }
        .compoundList()
        .navigationTitle(L10n.commonAdvancedSettings)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var irisNetworkSection: some View {
        Section {
            ListRow(label: .plain(title: UntranslatedL10n.screenIrisDisableAll), kind: .button {
                context.send(viewAction: .disableIrisNetwork)
            })
            networkToggle(UntranslatedL10n.screenIrisAnalytics, \.analyticsEnabled)
            networkToggle(UntranslatedL10n.screenIrisReports, \.reportsEnabled)
            networkToggle(UntranslatedL10n.screenIrisMaps, \.mapsEnabled)
            networkToggle(UntranslatedL10n.screenIrisCalls, \.callsEnabled)
            networkToggle(UntranslatedL10n.screenIrisScanner, \.scannerEnabled)
            networkToggle(UntranslatedL10n.screenIrisPush, \.pushEnabled)
            networkToggle(UntranslatedL10n.screenIrisLinks, \.externalLinksEnabled)
            networkToggle(UntranslatedL10n.screenIrisPreviews, \.linkPreviewsEnabled)
            networkToggle(UntranslatedL10n.screenIrisSuggestions, \.systemSuggestionsEnabled)
            DisclosureGroup(UntranslatedL10n.screenIrisEndpoints) {
                networkField(UntranslatedL10n.screenIrisAnalyticsHost, \.analyticsHost)
                networkField(UntranslatedL10n.screenIrisAnalyticsKey, \.analyticsKey)
                networkField(UntranslatedL10n.screenIrisRageshake, \.rageshakeURL)
                networkField(UntranslatedL10n.screenIrisSentry, \.sentryDSN)
                networkField(UntranslatedL10n.screenIrisMapBase, \.mapBaseURL)
                networkField(UntranslatedL10n.screenIrisMapKey, \.mapAPIKey)
                networkField(UntranslatedL10n.screenIrisMapLight, \.mapLightStyle)
                networkField(UntranslatedL10n.screenIrisMapDark, \.mapDarkStyle)
                networkField(UntranslatedL10n.screenIrisCallUrl, \.callURL)
                networkField(UntranslatedL10n.screenIrisScannerUrl, \.scannerURL)
                networkField(UntranslatedL10n.screenIrisPushUrl, \.pushGatewayURL)
            }
            ListRow(label: .plain(title: L10n.actionSave), kind: .button {
                context.send(viewAction: .saveIrisNetwork)
            })
        } header: {
            Text(UntranslatedL10n.screenIrisTitle).compoundListSectionHeader()
        } footer: {
            Text(UntranslatedL10n.screenIrisDescription).compoundListSectionFooter()
        }
    }
    
    private func networkToggle(_ title: String, _ keyPath: WritableKeyPath<IrisNetworkConfiguration, Bool>) -> some View {
        ListRow(label: .plain(title: title), kind: .toggle(Binding(get: {
            context.irisNetwork[keyPath: keyPath]
        }, set: { context.irisNetwork[keyPath: keyPath] = $0 })))
    }
    
    private func networkField(_ title: String, _ keyPath: WritableKeyPath<IrisNetworkConfiguration, String>) -> some View {
        ListRow(kind: .custom {
            VStack(alignment: .leading) {
                Text(title).font(.compound.bodySM).foregroundStyle(.compound.textSecondary)
                TextField(title, text: Binding(get: {
                    context.irisNetwork[keyPath: keyPath]
                }, set: { context.irisNetwork[keyPath: keyPath] = $0 }))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.compound.bodyMD)
            }
            .padding(.horizontal, ListRowPadding.horizontal)
            .padding(.vertical, ListRowPadding.vertical)
        })
    }
    
    @ViewBuilder
    private var moderationAndSafetySection: some View {
        let binding = Binding(get: {
            context.viewState.hideInviteAvatars
        }, set: { newValue in
            context.send(viewAction: .updateHideInviteAvatars(newValue))
        })
        
        Section {
            ListRow(label: .plain(title: L10n.screenAdvancedSettingsHideInviteAvatarsToggleTitle),
                    details: context.viewState.isWaitingHideInviteAvatars ? .isWaiting(true) : nil,
                    kind: .toggle(binding))
                .disabled(context.viewState.isWaitingHideInviteAvatars)
        } header: {
            Text(L10n.screenAdvancedSettingsModerationAndSafetySectionTitle)
                .compoundListSectionHeader()
        }
    }
    
    @ViewBuilder
    private var timelineMediaSection: some View {
        let binding = Binding(get: {
            context.viewState.timelineMediaVisibility
        }, set: { newValue in
            context.send(viewAction: .updateTimelineMediaVisibility(newValue))
        })
        
        Section {
            ListRow(label: .plain(title: L10n.screenAdvancedSettingsShowMediaTimelineTitle),
                    details: .isWaiting(context.viewState.isWaitingTimelineMediaVisibility),
                    kind: .inlinePicker(selection: binding,
                                        items: TimelineMediaVisibility.items))
                .disabled(context.viewState.isWaitingTimelineMediaVisibility)
        } header: {
            Text(L10n.screenAdvancedSettingsShowMediaTimelineTitle)
                .compoundListSectionHeader()
        } footer: {
            Text(L10n.screenAdvancedSettingsShowMediaTimelineSubtitle)
                .compoundListSectionFooter()
        }
    }
    
    @ViewBuilder
    private var liveLocationSection: some View {
        let binding = Binding(get: {
            Double(context.liveLocationMinimumDistanceUpdate)
        }, set: { newValue in
            context.liveLocationMinimumDistanceUpdate = Int(newValue)
        })
        
        Section {
            ListRow(kind: .custom {
                VStack(alignment: .leading, spacing: 0) {
                    Text(L10n.screenAdvancedSettingsLiveLocationUpdateDistance(context.liveLocationMinimumDistanceUpdate))
                        .font(.compound.bodyLG)
                        .foregroundStyle(.compound.textPrimary)
                        // The internal hidden label of the slider will read voice over
                        .accessibilityHidden(true)
                    Slider(value: binding, in: 1...100) {
                        Text(L10n.screenAdvancedSettingsLiveLocationUpdateDistance(context.liveLocationMinimumDistanceUpdate))
                    } minimumValueLabel: {
                        Text(Self.measurementFormatter.string(from: .init(value: 1,
                                                                          unit: UnitLength.meters)))
                            .font(.compound.bodyLG)
                            .foregroundStyle(.compound.textSecondary)
                            .padding(.trailing, 15)
                    } maximumValueLabel: {
                        Text(Self.measurementFormatter.string(from: .init(value: 100,
                                                                          unit: UnitLength.meters)))
                            .font(.compound.bodyLG)
                            .foregroundStyle(.compound.textSecondary)
                            .padding(.leading, 15)
                    }
                    .tint(.compound.iconAccentPrimary)
                }
                .padding(.horizontal, ListRowPadding.horizontal)
                .padding(.vertical, ListRowPadding.vertical)
            })
        } header: {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.screenAdvancedSettingsLiveLocationSectionTitle)
                    .compoundListSectionHeader()
                Text(L10n.screenAdvancedSettingsLiveLocationSectionDescription)
                    .font(.compound.bodyMD)
                    .foregroundStyle(.compound.textSecondary)
            }
        } footer: {
            Text(context.viewState.liveLocationUpdateFooterAttributedString)
                .compoundListSectionFooter()
        }
    }
}

private extension AppAppearance {
    var name: String {
        switch self {
        case .system:
            L10n.themeSystem
        case .light:
            L10n.themeLight
        case .dark:
            L10n.themeDark
        }
    }
}

// MARK: - Previews

struct AdvancedSettingsScreen_Previews: PreviewProvider, TestablePreview {
    static let viewModel = {
        let appSettings = AppSettings.volatile()
        return AdvancedSettingsScreenViewModel(advancedSettings: appSettings,
                                               analytics: AnalyticsServiceMock(.init()),
                                               clientProxy: ClientProxyMock(.init()),
                                               userIndicatorController: UserIndicatorControllerMock())
    }()
    
    static var previews: some View {
        ElementNavigationStack {
            AdvancedSettingsScreen(context: viewModel.context)
        }
    }
}

private extension TimelineMediaVisibility {
    static var items: [(title: String, tag: TimelineMediaVisibility)] {
        [(title: L10n.screenAdvancedSettingsShowMediaTimelineAlwaysHide, tag: .never),
         (title: L10n.screenAdvancedSettingsShowMediaTimelinePrivateRooms, tag: .privateOnly),
         (title: L10n.screenAdvancedSettingsShowMediaTimelineAlwaysShow, tag: .always)]
    }
}
