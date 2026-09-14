//
// Copyright 2025 Element Creations Ltd.
// Copyright 2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Combine
import LinkPresentation

class LinkMetadataProvider: LinkMetadataProviderProtocol {
    private let appSettings: AppSettings
    private var activeProviders = [UUID: LPMetadataProvider]()
    private var networkSubscription: AnyCancellable?
    
    init(appSettings: AppSettings = .volatile()) {
        self.appSettings = appSettings
        networkSubscription = appSettings.irisNetworkPublisher.dropFirst().receive(on: DispatchQueue.main).sink { [weak self] network in
            guard let self, !network.linkPreviewsEnabled else { return }
            self.activeProviders.values.forEach { $0.cancel() }
            self.activeProviders.removeAll()
            self.metadataItems.removeAll()
        }
    }
    
    private(set) var metadataItems = [URL: LinkMetadataProviderItem]()
    
    func fetchMetadataFor(url: URL) async -> Result<LinkMetadataProviderItem, Error> {
        guard appSettings.irisNetwork.linkPreviewsEnabled else { return .success(.init(metadata: nil)) }
        if let item = metadataItems[url] {
            return .success(item)
        }
        
        do {
            let identifier = UUID()
            let provider = LPMetadataProvider()
            activeProviders[identifier] = provider
            defer { activeProviders[identifier] = nil }
            let metadata = try await provider.startFetchingMetadata(for: url)
            guard appSettings.irisNetwork.linkPreviewsEnabled else { return .success(.init(metadata: nil)) }
            let item = LinkMetadataProviderItem(metadata: metadata)
            metadataItems[url] = item
            return .success(item)
        } catch {
            return .failure(error)
        }
    }
}
