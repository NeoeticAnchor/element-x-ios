//
// Copyright 2025 Element Creations Ltd.
// Copyright 2024-2025 New Vector Ltd.
//
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial.
// Please see LICENSE files in the repository root for full details.
//

import Foundation

nonisolated struct SessionDirectories: Hashable, Codable {
    let dataDirectory: URL
    let cacheDirectory: URL
    
    private enum CodingKeys: String, CodingKey {
        case dataDirectory, cacheDirectory
    }
    
    var dataPath: String {
        dataDirectory.path(percentEncoded: false)
    }
    
    var cachePath: String {
        cacheDirectory.path(percentEncoded: false)
    }
    
    // MARK: Data Management
    
    /// Removes the directories from disk if they have been created.
    func delete() {
        do {
            if FileManager.default.directoryExists(at: dataDirectory) {
                try FileManager.default.removeItem(at: dataDirectory)
            }
        } catch {
            MXLog.failure("Failed deleting the session data: \(error)")
        }
        do {
            if FileManager.default.directoryExists(at: cacheDirectory) {
                try FileManager.default.removeItem(at: cacheDirectory)
            }
        } catch {
            MXLog.failure("Failed deleting the session caches: \(error)")
        }
    }
    
    /// Deletes the Rust state store and event cache data, leaving the crypto store and both
    /// session directories in place along with any other data that may have been written in them.
    func deleteTransientUserData() {
        do {
            let prefix = "matrix-sdk-state"
            try deleteFiles(at: dataDirectory, with: prefix)
        } catch {
            MXLog.failure("Failed clearing state store: \(error)")
        }
        do {
            let prefix = "matrix-sdk-event-cache"
            try deleteFiles(at: cacheDirectory, with: prefix)
        } catch {
            MXLog.failure("Failed clearing event cache store: \(error)")
        }
    }
    
    /// Check that mission critical files (the crypto db) are still in the right place when restoring a session
    /// iOS might decide to move the app with its user defaults and keychain but without
    /// some of the files stored in the shared container e.g. after a device transfer, offloading etc.
    /// If that happens we should fail the session restoration.
    func isNonTransientUserDataValid() -> Bool {
        FileManager.default.fileExists(atPath: dataPath.appending("/matrix-sdk-crypto.sqlite3"))
    }
    
    private func deleteFiles(at url: URL, with prefix: String) throws {
        let sessionDirectoryContents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        for url in sessionDirectoryContents where url.lastPathComponent.hasPrefix(prefix) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

nonisolated extension SessionDirectories {
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        dataDirectory = try Self.relocated(values.decode(URL.self, forKey: .dataDirectory), under: .sessionsBaseDirectory)
        cacheDirectory = try Self.relocated(values.decode(URL.self, forKey: .cacheDirectory), under: .sessionCachesBaseDirectory)
    }
    
    func relocatedToCurrentContainer() -> Self {
        .init(dataDirectory: Self.relocated(dataDirectory, under: .sessionsBaseDirectory),
              cacheDirectory: Self.relocated(cacheDirectory, under: .sessionCachesBaseDirectory))
    }
    
    // iOS can relocate the sandbox on update. Persisted absolute URLs must follow it.
    private static func relocated(_ directory: URL, under root: URL) -> URL {
        guard directory.isFileURL,
              UUID(uuidString: directory.lastPathComponent) != nil,
              directory.deletingLastPathComponent().pathComponents.suffix(4) == root.pathComponents.suffix(4) else {
            return directory
        }
        return root.appending(component: directory.lastPathComponent)
    }
    
    /// Creates a fresh set of session directories for a new user.
    init() {
        let sessionDirectoryName = UUID().uuidString
        dataDirectory = .sessionsBaseDirectory.appending(component: sessionDirectoryName)
        cacheDirectory = .sessionCachesBaseDirectory.appending(component: sessionDirectoryName)
    }
    
    /// Creates the session directories for a user who has a single session directory stored without a separate caches directory.
    init(dataDirectory: URL) {
        self.dataDirectory = Self.relocated(dataDirectory, under: .sessionsBaseDirectory)
        cacheDirectory = .sessionCachesBaseDirectory.appending(component: dataDirectory.lastPathComponent)
    }
}

nonisolated extension SessionDirectories: CustomStringConvertible {
    var description: String {
        "Data: \(dataPath) Caches: \(cachePath)"
    }
}
