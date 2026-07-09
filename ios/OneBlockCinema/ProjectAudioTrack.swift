import Foundation
import GRDB

nonisolated enum ProjectAudioTrackKind: String, Codable, CaseIterable, Sendable, Hashable {
    case voiceover
    case ambient
}

nonisolated struct ProjectAudioTrack: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let kind: ProjectAudioTrackKind
    let fileURL: URL
    let duration: TimeInterval
    var volume: Double

    init(
        id: UUID = UUID(),
        kind: ProjectAudioTrackKind,
        fileURL: URL,
        duration: TimeInterval,
        volume: Double
    ) {
        self.id = id
        self.kind = kind
        self.fileURL = fileURL
        self.duration = duration
        self.volume = min(max(volume, 0), 1)
    }
}

extension SessionStorage {
    func copyAudio(_ sourceURL: URL, for sessionId: UUID) throws -> URL {
        let directory = try draftsDirectory
            .appendingPathComponent(sessionId.uuidString, isDirectory: true)
            .appendingPathComponent("Audio", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let ext = sourceURL.pathExtension.isEmpty ? "m4a" : sourceURL.pathExtension
        let destination = directory.appendingPathComponent("audio_\(UUID().uuidString).\(ext)")
        try fileManager.copyItem(at: sourceURL, to: destination)
        return destination
    }
}

nonisolated enum ProjectAudioTrackPersistence {
    static func load(
        sessionId: String,
        rootDirectory: URL,
        from db: Database
    ) throws -> [ProjectAudioTrack] {
        let rows = try Row.fetchAll(
            db,
            sql: "SELECT * FROM local_audio_tracks WHERE session_id = ? ORDER BY kind",
            arguments: [sessionId]
        )
        return rows.compactMap { row in
            guard let id = UUID(uuidString: row["id"]),
                  let kind = ProjectAudioTrackKind(rawValue: row["kind"]) else { return nil }
            let path: String = row["path"]
            let pathKind: String = row["path_kind"]
            let url = resolvedURL(path: path, kind: pathKind, rootDirectory: rootDirectory)
            return ProjectAudioTrack(
                id: id,
                kind: kind,
                fileURL: url,
                duration: row["duration"],
                volume: row["volume"]
            )
        }
    }

    static func persist(
        _ tracks: [ProjectAudioTrack],
        sessionId: UUID,
        rootDirectory: URL,
        in db: Database
    ) throws {
        try db.execute(
            sql: "DELETE FROM local_audio_tracks WHERE session_id = ?",
            arguments: [sessionId.uuidString]
        )
        for track in tracks {
            let stored = storedPath(for: track.fileURL, rootDirectory: rootDirectory)
            try db.execute(
                sql: """
                INSERT INTO local_audio_tracks (
                    id, session_id, kind, path, path_kind, duration, volume
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                arguments: [
                    track.id.uuidString,
                    sessionId.uuidString,
                    track.kind.rawValue,
                    stored.path,
                    stored.kind,
                    track.duration,
                    track.volume
                ]
            )
        }
    }

    private static func storedPath(for url: URL, rootDirectory: URL) -> (path: String, kind: String) {
        let standardizedURL = url.standardizedFileURL
        let root = rootDirectory.standardizedFileURL
        if DraftStorageMaintenance.isDescendant(standardizedURL, of: root) {
            return (String(standardizedURL.path.dropFirst(root.path.count + 1)), "relative")
        }
        return (standardizedURL.path, "absolute")
    }

    private static func resolvedURL(path: String, kind: String, rootDirectory: URL) -> URL {
        if kind == "relative" {
            return rootDirectory.appendingPathComponent(path).standardizedFileURL
        }
        return URL(fileURLWithPath: path).standardizedFileURL
    }
}
