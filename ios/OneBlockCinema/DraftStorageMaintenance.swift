import Foundation
import GRDB

nonisolated struct DraftStorageHealth: Sendable, Hashable {
    let missingClipCount: Int
    let recoveryIssueCount: Int
    let reclaimableFileCount: Int
    let reclaimableBytes: Int64

    static let empty = DraftStorageHealth(
        missingClipCount: 0,
        recoveryIssueCount: 0,
        reclaimableFileCount: 0,
        reclaimableBytes: 0
    )

    var needsAttention: Bool {
        missingClipCount > 0 || recoveryIssueCount > 0 || reclaimableFileCount > 0
    }
}

nonisolated struct DraftStorageCleanupResult: Sendable, Hashable {
    let removedFileCount: Int
    let reclaimedBytes: Int64
}

extension SessionStorage {
    func auditStorage(now: Date = Date()) throws -> DraftStorageHealth {
        let queue = try database()
        try migrateLegacyIfNeeded(in: queue)
        let root = try rootDirectory
        let drafts = try draftsDirectory
        let manager = fileManager
        let snapshot = try queue.read { db in
            try DraftStorageMaintenance.storageSnapshot(
                rootDirectory: root,
                draftsDirectory: drafts,
                fileManager: manager,
                from: db
            )
        }
        let candidates = try DraftStorageMaintenance.reclaimableFiles(
            in: drafts,
            excluding: snapshot.referencedPaths,
            fileManager: manager,
            now: now
        )
        return DraftStorageHealth(
            missingClipCount: snapshot.missingClipCount,
            recoveryIssueCount: snapshot.recoveryIssueCount,
            reclaimableFileCount: candidates.count,
            reclaimableBytes: candidates.reduce(0) { $0 + $1.byteCount }
        )
    }

    func cleanupOrphanedMedia(now: Date = Date()) throws -> DraftStorageCleanupResult {
        let queue = try database()
        try migrateLegacyIfNeeded(in: queue)
        let root = try rootDirectory
        let drafts = try draftsDirectory
        let manager = fileManager
        let referencedPaths = try queue.read { db in
            try DraftStorageMaintenance.storageSnapshot(
                rootDirectory: root,
                draftsDirectory: drafts,
                fileManager: manager,
                from: db
            ).referencedPaths
        }
        let candidates = try DraftStorageMaintenance.reclaimableFiles(
            in: drafts,
            excluding: referencedPaths,
            fileManager: manager,
            now: now
        )

        for candidate in candidates {
            guard DraftStorageMaintenance.isDescendant(candidate.url, of: drafts) else {
                throw SessionStorageError.unsafeMediaPath
            }
            try manager.removeItem(at: candidate.url)
        }
        try DraftStorageMaintenance.removeEmptyDraftDirectories(
            in: drafts,
            fileManager: manager
        )

        return DraftStorageCleanupResult(
            removedFileCount: candidates.count,
            reclaimedBytes: candidates.reduce(0) { $0 + $1.byteCount }
        )
    }
}

nonisolated enum DraftStorageMaintenance {
    static let orphanGracePeriod: TimeInterval = 24 * 60 * 60

    struct StorageSnapshot {
        let referencedPaths: Set<String>
        let missingClipCount: Int
        let recoveryIssueCount: Int
    }

    struct ReclaimableFile {
        let url: URL
        let byteCount: Int64
    }

    static func storageSnapshot(
        rootDirectory: URL,
        draftsDirectory: URL,
        fileManager: FileManager,
        from db: Database
    ) throws -> StorageSnapshot {
        let rows = try Row.fetchAll(
            db,
            sql: "SELECT path, path_kind, thumbnail_path, thumbnail_path_kind FROM clips"
        )
        var referencedPaths = Set<String>()
        var missingClipCount = 0

        for row in rows {
            let path: String = row["path"]
            let kind: String = row["path_kind"]
            let mediaURL = resolvedURL(path: path, kind: kind, rootDirectory: rootDirectory)
            if !fileManager.fileExists(atPath: mediaURL.path) {
                missingClipCount += 1
            }
            if isDescendant(mediaURL, of: draftsDirectory) {
                referencedPaths.insert(mediaURL.standardizedFileURL.path)
            }

            let thumbnailPath: String? = row["thumbnail_path"]
            let thumbnailKind: String? = row["thumbnail_path_kind"]
            if let thumbnailPath, let thumbnailKind {
                let thumbnailURL = resolvedURL(
                    path: thumbnailPath,
                    kind: thumbnailKind,
                    rootDirectory: rootDirectory
                )
                if isDescendant(thumbnailURL, of: draftsDirectory) {
                    referencedPaths.insert(thumbnailURL.standardizedFileURL.path)
                }
            }
        }

        return StorageSnapshot(
            referencedPaths: referencedPaths,
            missingClipCount: missingClipCount,
            recoveryIssueCount: try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM recovery_issues") ?? 0
        )
    }

    static func reclaimableFiles(
        in draftsDirectory: URL,
        excluding referencedPaths: Set<String>,
        fileManager: FileManager,
        now: Date
    ) throws -> [ReclaimableFile] {
        guard fileManager.fileExists(atPath: draftsDirectory.path) else { return [] }
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .contentModificationDateKey,
            .fileAllocatedSizeKey,
            .fileSizeKey,
        ]
        guard let enumerator = fileManager.enumerator(
            at: draftsDirectory,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsPackageDescendants]
        ) else { return [] }

        var candidates: [ReclaimableFile] = []
        for case let fileURL as URL in enumerator {
            let standardizedURL = fileURL.standardizedFileURL
            guard isDescendant(standardizedURL, of: draftsDirectory) else { continue }
            let values = try standardizedURL.resourceValues(forKeys: keys)
            guard values.isRegularFile == true || values.isSymbolicLink == true else { continue }
            guard !referencedPaths.contains(standardizedURL.path) else { continue }
            guard let modifiedAt = values.contentModificationDate,
                  now.timeIntervalSince(modifiedAt) >= orphanGracePeriod else { continue }
            let byteCount = Int64(values.fileAllocatedSize ?? values.fileSize ?? 0)
            candidates.append(ReclaimableFile(url: standardizedURL, byteCount: byteCount))
        }
        return candidates
    }

    static func removeEmptyDraftDirectories(in draftsDirectory: URL, fileManager: FileManager) throws {
        guard fileManager.fileExists(atPath: draftsDirectory.path),
              let enumerator = fileManager.enumerator(
                  at: draftsDirectory,
                  includingPropertiesForKeys: [.isDirectoryKey],
                  options: [.skipsPackageDescendants]
              ) else { return }
        let directories = enumerator.compactMap { item -> URL? in
            guard let url = item as? URL,
                  (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return nil }
            return url.standardizedFileURL
        }.sorted { $0.pathComponents.count > $1.pathComponents.count }

        for directory in directories where isDescendant(directory, of: draftsDirectory) {
            if try fileManager.contentsOfDirectory(atPath: directory.path).isEmpty {
                try fileManager.removeItem(at: directory)
            }
        }
    }

    static func isDescendant(_ candidate: URL, of root: URL) -> Bool {
        let candidatePath = candidate.standardizedFileURL.path
        let rootPath = root.standardizedFileURL.path
        return candidatePath == rootPath || candidatePath.hasPrefix(rootPath + "/")
    }

    private static func resolvedURL(path: String, kind: String, rootDirectory: URL) -> URL {
        if kind == "relative" {
            return rootDirectory.appendingPathComponent(path).standardizedFileURL
        }
        return URL(fileURLWithPath: path).standardizedFileURL
    }
}
