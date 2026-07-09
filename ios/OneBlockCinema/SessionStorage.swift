import Foundation
import GRDB

nonisolated struct DraftRecoveryIssue: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let source: String
    let message: String
    let createdAt: Date
}

nonisolated enum SessionStorageError: LocalizedError, Sendable {
    case unsafeMediaPath
    case missingOutboxOperation

    var errorDescription: String? {
        switch self {
        case .unsafeMediaPath:
            "One-Block Cinema refused to delete a media file outside its private storage directory."
        case .missingOutboxOperation:
            "The queued sync operation could not be found."
        }
    }
}

actor SessionStorage {
    private enum Constants {
        static let legacyMigrationKey = "legacy-json-migration-v1"
        static let relativePathKind = "relative"
        static let absolutePathKind = "absolute"
    }

    private let userDefaults: UserDefaults
    private let sessionsKey: String
    let fileManager: FileManager
    private let configuredRootDirectory: URL?
    private var databaseQueue: DatabaseQueue?

    init(
        userDefaults: UserDefaults = .standard,
        sessionsKey: String = "saved_film_sessions",
        fileManager: FileManager = .default,
        rootDirectory: URL? = nil
    ) {
        self.userDefaults = userDefaults
        self.sessionsKey = sessionsKey
        self.fileManager = fileManager
        configuredRootDirectory = rootDirectory
    }

    var rootDirectory: URL {
        get throws {
            if let configuredRootDirectory {
                return configuredRootDirectory.standardizedFileURL
            }

            let base = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            return base.appendingPathComponent("OneBlockCinema", isDirectory: true).standardizedFileURL
        }
    }

    private var databaseFile: URL {
        get throws { try rootDirectory.appendingPathComponent("projects.sqlite") }
    }

    private var legacySessionsFile: URL {
        get throws { try rootDirectory.appendingPathComponent("sessions.json") }
    }

    var draftsDirectory: URL {
        get throws { try rootDirectory.appendingPathComponent("Drafts", isDirectory: true) }
    }

    private func draftDirectory(for sessionId: UUID) throws -> URL {
        try rootDirectory
            .appendingPathComponent("Drafts", isDirectory: true)
            .appendingPathComponent(sessionId.uuidString, isDirectory: true)
    }

    private func mediaDirectory(for sessionId: UUID) throws -> URL {
        try draftDirectory(for: sessionId).appendingPathComponent("Media", isDirectory: true)
    }

    private func ensureDirectory(_ url: URL) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func database() throws -> DatabaseQueue {
        if let databaseQueue {
            return databaseQueue
        }

        let root = try rootDirectory
        try ensureDirectory(root)
        let queue = try DatabaseQueue(path: databaseFile.path)
        try Self.migrator.migrate(queue)
        databaseQueue = queue
        return queue
    }

    func saveSessions(_ sessions: [FilmSession]) throws {
        let queue = try database()
        try migrateLegacyIfNeeded(in: queue)
        let root = try rootDirectory
        try queue.write { db in
            try Self.persist(sessions, rootDirectory: root, in: db)
        }
    }

    func loadSessions() throws -> [FilmSession] {
        let queue = try database()
        try migrateLegacyIfNeeded(in: queue)
        let root = try rootDirectory
        let fileManager = fileManager

        return try queue.write { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT id, payload, recovery_state FROM sessions ORDER BY created_at DESC"
            )

            return rows.compactMap { row in
                let sessionId: String = row["id"]
                let payload: Data = row["payload"]

                do {
                    let metadata = try JSONDecoder().decode(StoredSessionMetadata.self, from: payload)
                    let clips = try Self.loadClips(
                        for: sessionId,
                        rootDirectory: root,
                        fileManager: fileManager,
                        from: db
                    )
                    return metadata.makeSession(clips: clips)
                } catch {
                    let recoveryState: String = row["recovery_state"]
                    if recoveryState != "unreadable" {
                        try? Self.recordRecoveryIssue(
                            source: "database-session:\(sessionId)",
                            message: error.localizedDescription,
                            in: db
                        )
                    }
                    try? db.execute(
                        sql: "UPDATE sessions SET recovery_state = 'unreadable', recovery_reason = ? WHERE id = ?",
                        arguments: [error.localizedDescription, sessionId]
                    )
                    return nil
                }
            }
        }
    }

    func loadRecoveryIssues() throws -> [DraftRecoveryIssue] {
        let queue = try database()
        return try queue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT id, source, message, created_at FROM recovery_issues ORDER BY created_at DESC"
            )
            return rows.compactMap { row in
                guard let id = UUID(uuidString: row["id"]) else { return nil }
                let createdAt: Double = row["created_at"]
                return DraftRecoveryIssue(
                    id: id,
                    source: row["source"],
                    message: row["message"],
                    createdAt: Date(timeIntervalSince1970: createdAt)
                )
            }
        }
    }

    func copyClip(_ sourceURL: URL, for sessionId: UUID) throws -> URL {
        let directory = try mediaDirectory(for: sessionId)
        try ensureDirectory(directory)

        let ext = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let destination = directory.appendingPathComponent("clip_\(UUID().uuidString).\(ext)")

        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        try fileManager.copyItem(at: sourceURL, to: destination)
        return destination
    }

    func deleteClipFile(at url: URL) throws {
        guard DraftStorageMaintenance.isDescendant(url, of: try draftsDirectory) else {
            throw SessionStorageError.unsafeMediaPath
        }
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    func deleteDraft(for sessionId: UUID) throws {
        let directory = try draftDirectory(for: sessionId)
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }

        let queue = try database()
        try queue.write { db in
            try db.execute(sql: "DELETE FROM sessions WHERE id = ?", arguments: [sessionId.uuidString])
        }
    }

    func enqueueSyncOperation(
        aggregateId: UUID,
        kind: SyncOperationKind,
        payload: Data,
        idempotencyKey: UUID = UUID(),
        createdAt: Date = Date()
    ) throws -> SyncOutboxOperation {
        let queue = try database()
        return try queue.write { db in
            try db.execute(
                sql: """
                    INSERT OR IGNORE INTO sync_outbox (
                        id, aggregate_id, operation, payload, created_at,
                        attempt_count, next_attempt_at, state, last_error
                    ) VALUES (?, ?, ?, ?, ?, 0, NULL, 'pending', NULL)
                    """,
                arguments: [
                    idempotencyKey.uuidString,
                    aggregateId.uuidString,
                    kind.rawValue,
                    payload,
                    createdAt.timeIntervalSince1970,
                ]
            )
            guard let operation = try Self.fetchSyncOperation(id: idempotencyKey, from: db) else {
                throw SessionStorageError.missingOutboxOperation
            }
            return operation
        }
    }

    func loadPendingSyncOperations(limit: Int = 50, now: Date = Date()) throws -> [SyncOutboxOperation] {
        guard limit > 0 else { return [] }
        let queue = try database()
        return try queue.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT * FROM sync_outbox
                    WHERE state IN ('pending', 'failed')
                      AND (next_attempt_at IS NULL OR next_attempt_at <= ?)
                    ORDER BY created_at ASC
                    LIMIT ?
                    """,
                arguments: [now.timeIntervalSince1970, limit]
            )
            return rows.compactMap(Self.decodeSyncOperation)
        }
    }

    func markProcessing(id: UUID) throws {
        let queue = try database()
        try queue.write { db in
            try db.execute(
                sql: "UPDATE sync_outbox SET state = 'processing', last_error = NULL WHERE id = ?",
                arguments: [id.uuidString]
            )
        }
    }

    func markFailed(id: UUID, error: String, retryAt: Date) throws {
        let queue = try database()
        try queue.write { db in
            try db.execute(
                sql: """
                    UPDATE sync_outbox
                    SET state = 'failed',
                        attempt_count = attempt_count + 1,
                        next_attempt_at = ?,
                        last_error = ?
                    WHERE id = ?
                    """,
                arguments: [retryAt.timeIntervalSince1970, error, id.uuidString]
            )
        }
    }

    func markCompleted(id: UUID) throws {
        let queue = try database()
        try queue.write { db in
            try db.execute(
                sql: """
                    UPDATE sync_outbox
                    SET state = 'completed', next_attempt_at = NULL, last_error = NULL
                    WHERE id = ?
                    """,
                arguments: [id.uuidString]
            )
        }
    }

    func migrateLegacyIfNeeded(in queue: DatabaseQueue) throws {
        let alreadyMigrated = try queue.read { db in
            try String.fetchOne(
                db,
                sql: "SELECT value FROM app_metadata WHERE key = ?",
                arguments: [Constants.legacyMigrationKey]
            ) != nil
        }
        guard !alreadyMigrated else { return }

        var candidates: [(source: String, data: Data)] = []
        let legacyFile = try legacySessionsFile
        if fileManager.fileExists(atPath: legacyFile.path) {
            do {
                candidates.append(("sessions.json", try Data(contentsOf: legacyFile)))
            } catch {
                try queue.write { db in
                    try Self.recordRecoveryIssue(
                        source: "sessions.json",
                        message: "The legacy draft file could not be read: \(error.localizedDescription)",
                        in: db
                    )
                }
            }
        }
        if let data = userDefaults.data(forKey: sessionsKey) {
            candidates.append(("UserDefaults:\(sessionsKey)", data))
        }

        var migratedSessions: [FilmSession]?
        for candidate in candidates {
            do {
                migratedSessions = try JSONDecoder().decode([FilmSession].self, from: candidate.data)
                break
            } catch {
                try queue.write { db in
                    try Self.recordRecoveryIssue(
                        source: candidate.source,
                        message: "The legacy draft metadata was preserved but could not be decoded: \(error.localizedDescription)",
                        in: db
                    )
                }
            }
        }

        let root = try rootDirectory
        try queue.write { db in
            if let migratedSessions {
                try Self.persist(migratedSessions, rootDirectory: root, in: db)
            }
            try db.execute(
                sql: "INSERT OR REPLACE INTO app_metadata (key, value) VALUES (?, ?)",
                arguments: [Constants.legacyMigrationKey, ISO8601DateFormatter().string(from: Date())]
            )
        }
    }

    private static let migrator: DatabaseMigrator = {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("create-local-project-store-v1") { db in
            try db.execute(sql: """
                CREATE TABLE sessions (
                    id TEXT PRIMARY KEY NOT NULL,
                    created_at DOUBLE NOT NULL,
                    updated_at DOUBLE NOT NULL,
                    completed_at DOUBLE,
                    payload BLOB NOT NULL,
                    recovery_state TEXT NOT NULL DEFAULT 'healthy',
                    recovery_reason TEXT
                );

                CREATE TABLE clips (
                    id TEXT PRIMARY KEY NOT NULL,
                    session_id TEXT NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
                    prompt_id TEXT NOT NULL,
                    path TEXT NOT NULL,
                    path_kind TEXT NOT NULL,
                    thumbnail_path TEXT,
                    thumbnail_path_kind TEXT,
                    duration DOUBLE NOT NULL,
                    created_at DOUBLE NOT NULL,
                    show_title INTEGER NOT NULL,
                    title_text TEXT NOT NULL,
                    media_status TEXT NOT NULL DEFAULT 'available'
                );

                CREATE INDEX clips_session_id ON clips(session_id);

                CREATE TABLE sync_outbox (
                    id TEXT PRIMARY KEY NOT NULL,
                    aggregate_id TEXT NOT NULL,
                    operation TEXT NOT NULL,
                    payload BLOB NOT NULL,
                    created_at DOUBLE NOT NULL,
                    attempt_count INTEGER NOT NULL DEFAULT 0,
                    next_attempt_at DOUBLE,
                    state TEXT NOT NULL DEFAULT 'pending'
                );

                CREATE INDEX sync_outbox_state_next_attempt ON sync_outbox(state, next_attempt_at);

                CREATE TABLE app_metadata (
                    key TEXT PRIMARY KEY NOT NULL,
                    value TEXT NOT NULL
                );

                CREATE TABLE recovery_issues (
                    id TEXT PRIMARY KEY NOT NULL,
                    source TEXT NOT NULL,
                    message TEXT NOT NULL,
                    created_at DOUBLE NOT NULL
                );
                """)
        }
        migrator.registerMigration("add-outbox-error-v2") { db in
            try db.execute(sql: "ALTER TABLE sync_outbox ADD COLUMN last_error TEXT")
        }
        migrator.registerMigration("add-clip-editing-v3") { db in
            try db.execute(sql: "ALTER TABLE clips ADD COLUMN trim_start DOUBLE NOT NULL DEFAULT 0")
            try db.execute(sql: "ALTER TABLE clips ADD COLUMN trim_end DOUBLE")
        }
        migrator.registerMigration("add-clip-volume-v4") { db in
            try db.execute(sql: "ALTER TABLE clips ADD COLUMN volume DOUBLE NOT NULL DEFAULT 1")
        }
        migrator.registerMigration("add-clip-transition-v5") { db in
            try db.execute(sql: "ALTER TABLE clips ADD COLUMN transition_style TEXT NOT NULL DEFAULT 'cut'")
        }
        migrator.registerMigration("add-render-recovery-v6") { db in
            try db.execute(sql: """
                CREATE TABLE local_render_jobs (
                    id TEXT PRIMARY KEY NOT NULL,
                    session_id TEXT NOT NULL UNIQUE REFERENCES sessions(id) ON DELETE CASCADE,
                    status TEXT NOT NULL CHECK (
                        status IN ('rendering', 'completed', 'cancelled', 'failed', 'interrupted', 'dismissed')
                    ),
                    started_at DOUBLE NOT NULL,
                    updated_at DOUBLE NOT NULL,
                    failure_reason TEXT
                );

                CREATE INDEX local_render_jobs_status_updated
                ON local_render_jobs(status, updated_at);
                """)
        }
        return migrator
    }()

    private static func persist(_ sessions: [FilmSession], rootDirectory: URL, in db: Database) throws {
        let incomingIds = Set(sessions.map { $0.id.uuidString })
        let storedIds = try String.fetchAll(db, sql: "SELECT id FROM sessions")
        for storedId in storedIds where !incomingIds.contains(storedId) {
            try db.execute(sql: "DELETE FROM sessions WHERE id = ?", arguments: [storedId])
        }

        let encoder = JSONEncoder()
        for session in sessions {
            let metadata = StoredSessionMetadata(session: session)
            let payload = try encoder.encode(metadata)
            try db.execute(
                sql: """
                    INSERT INTO sessions (
                        id, created_at, updated_at, completed_at, payload, recovery_state, recovery_reason
                    ) VALUES (?, ?, ?, ?, ?, 'healthy', NULL)
                    ON CONFLICT(id) DO UPDATE SET
                        updated_at = excluded.updated_at,
                        completed_at = excluded.completed_at,
                        payload = excluded.payload,
                        recovery_state = 'healthy',
                        recovery_reason = NULL
                    """,
                arguments: [
                    session.id.uuidString,
                    session.createdAt.timeIntervalSince1970,
                    Date().timeIntervalSince1970,
                    session.completedAt?.timeIntervalSince1970,
                    payload,
                ]
            )

            try db.execute(sql: "DELETE FROM clips WHERE session_id = ?", arguments: [session.id.uuidString])
            for clip in session.clips {
                let mediaPath = storedPath(for: clip.fileURL, rootDirectory: rootDirectory)
                let thumbnailPath = clip.thumbnailURL.map { storedPath(for: $0, rootDirectory: rootDirectory) }
                try db.execute(
                    sql: """
                        INSERT INTO clips (
                            id, session_id, prompt_id, path, path_kind,
                            thumbnail_path, thumbnail_path_kind, duration, created_at,
                            show_title, title_text, media_status, trim_start, trim_end, volume, transition_style
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                        """,
                    arguments: [
                        clip.id.uuidString,
                        session.id.uuidString,
                        clip.promptId.uuidString,
                        mediaPath.path,
                        mediaPath.kind,
                        thumbnailPath?.path,
                        thumbnailPath?.kind,
                        clip.duration,
                        clip.createdAt.timeIntervalSince1970,
                        clip.showTitle,
                        clip.titleText,
                        clip.mediaStatus.rawValue,
                        clip.trimStart,
                        clip.trimEnd,
                        clip.volume,
                        clip.transitionStyle.rawValue,
                    ]
                )
            }
        }
    }

    private static func loadClips(
        for sessionId: String,
        rootDirectory: URL,
        fileManager: FileManager,
        from db: Database
    ) throws -> [FilmClip] {
        let rows = try Row.fetchAll(
            db,
            sql: "SELECT * FROM clips WHERE session_id = ? ORDER BY created_at ASC",
            arguments: [sessionId]
        )

        return rows.compactMap { (row: Row) -> FilmClip? in
            guard
                let id = UUID(uuidString: row["id"]),
                let promptId = UUID(uuidString: row["prompt_id"])
            else { return nil }

            let path: String = row["path"]
            let pathKind: String = row["path_kind"]
            let fileURL = resolvedURL(path: path, kind: pathKind, rootDirectory: rootDirectory)
            let thumbnailPath: String? = row["thumbnail_path"]
            let thumbnailPathKind: String? = row["thumbnail_path_kind"]
            let thumbnailURL: URL? = if let thumbnailPath, let thumbnailPathKind {
                resolvedURL(path: thumbnailPath, kind: thumbnailPathKind, rootDirectory: rootDirectory)
            } else {
                nil
            }
            let rawStatus: String = row["media_status"]
            let storedStatus = ClipMediaStatus(rawValue: rawStatus) ?? .available
            let status: ClipMediaStatus = fileManager.fileExists(atPath: fileURL.path) ? storedStatus : .missing
            let createdAt: Double = row["created_at"]

            return FilmClip(
                id: id,
                promptId: promptId,
                fileURL: fileURL,
                thumbnailURL: thumbnailURL,
                duration: row["duration"],
                createdAt: Date(timeIntervalSince1970: createdAt),
                showTitle: row["show_title"],
                titleText: row["title_text"],
                mediaStatus: status,
                trimStart: row["trim_start"],
                trimEnd: row["trim_end"],
                volume: row["volume"],
                transitionStyle: TransitionStyle(rawValue: row["transition_style"]) ?? .cut
            )
        }
    }

    private static func recordRecoveryIssue(source: String, message: String, in db: Database) throws {
        try db.execute(
            sql: "INSERT INTO recovery_issues (id, source, message, created_at) VALUES (?, ?, ?, ?)",
            arguments: [UUID().uuidString, source, message, Date().timeIntervalSince1970]
        )
    }

    private static func fetchSyncOperation(id: UUID, from db: Database) throws -> SyncOutboxOperation? {
        guard let row = try Row.fetchOne(
            db,
            sql: "SELECT * FROM sync_outbox WHERE id = ?",
            arguments: [id.uuidString]
        ) else { return nil }
        return decodeSyncOperation(row)
    }

    private static func decodeSyncOperation(_ row: Row) -> SyncOutboxOperation? {
        guard
            let id = UUID(uuidString: row["id"]),
            let aggregateId = UUID(uuidString: row["aggregate_id"]),
            let kind = SyncOperationKind(rawValue: row["operation"]),
            let state = SyncOperationState(rawValue: row["state"])
        else { return nil }

        let createdAt: Double = row["created_at"]
        let nextAttemptAt: Double? = row["next_attempt_at"]
        return SyncOutboxOperation(
            id: id,
            aggregateId: aggregateId,
            kind: kind,
            payload: row["payload"],
            createdAt: Date(timeIntervalSince1970: createdAt),
            attemptCount: row["attempt_count"],
            nextAttemptAt: nextAttemptAt.map(Date.init(timeIntervalSince1970:)),
            state: state,
            lastError: row["last_error"]
        )
    }

    private static func storedPath(for url: URL, rootDirectory: URL) -> (path: String, kind: String) {
        let standardizedURL = url.standardizedFileURL
        let standardizedRoot = rootDirectory.standardizedFileURL
        if isDescendant(standardizedURL, of: standardizedRoot) {
            let prefixLength = standardizedRoot.path.count + 1
            return (String(standardizedURL.path.dropFirst(prefixLength)), Constants.relativePathKind)
        }
        return (standardizedURL.path, Constants.absolutePathKind)
    }

    private static func resolvedURL(path: String, kind: String, rootDirectory: URL) -> URL {
        if kind == Constants.relativePathKind {
            return rootDirectory.appendingPathComponent(path).standardizedFileURL
        }
        return URL(fileURLWithPath: path).standardizedFileURL
    }

    private static func isDescendant(_ candidate: URL, of root: URL) -> Bool {
        let candidatePath = candidate.standardizedFileURL.path
        let rootPath = root.standardizedFileURL.path
        return candidatePath == rootPath || candidatePath.hasPrefix(rootPath + "/")
    }
}

private nonisolated struct StoredSessionMetadata: Codable, Sendable {
    let id: UUID
    let theme: FilmTheme
    let templateId: String?
    let templateSchemaVersion: Int?
    let templateTitle: String?
    let templateOutcome: String?
    let aspectRatio: TemplateAspectRatio?
    let durationTarget: TemplateDurationTarget?
    let assemblyGuidance: TemplateAssemblyGuidance?
    let prompts: [ShotPrompt]
    let clipOrder: [UUID]?
    let pacingStyle: PacingStyle
    let editStyle: EditStyle
    let useAmbientSoundtrack: Bool
    let revision: Int?
    let syncState: SyncState?
    let syncEnabled: Bool?
    let recoveredFromProjectId: UUID?
    let createdAt: Date
    let completedAt: Date?
    let title: String

    init(session: FilmSession) {
        id = session.id
        theme = session.theme
        templateId = session.templateId
        templateSchemaVersion = session.templateSchemaVersion
        templateTitle = session.templateTitle
        templateOutcome = session.templateOutcome
        aspectRatio = session.aspectRatio
        durationTarget = session.durationTarget
        assemblyGuidance = session.assemblyGuidance
        prompts = session.prompts
        clipOrder = session.clipOrder
        pacingStyle = session.pacingStyle
        editStyle = session.editStyle
        useAmbientSoundtrack = session.useAmbientSoundtrack
        revision = session.revision
        syncState = session.syncState
        syncEnabled = session.syncEnabled
        recoveredFromProjectId = session.recoveredFromProjectId
        createdAt = session.createdAt
        completedAt = session.completedAt
        title = session.title
    }

    func makeSession(clips: [FilmClip]) -> FilmSession {
        FilmSession(
            id: id,
            theme: theme,
            templateId: templateId,
            templateSchemaVersion: templateSchemaVersion,
            templateTitle: templateTitle,
            templateOutcome: templateOutcome,
            aspectRatio: aspectRatio,
            durationTarget: durationTarget,
            assemblyGuidance: assemblyGuidance,
            prompts: prompts,
            clips: clips,
            clipOrder: clipOrder ?? [],
            pacingStyle: pacingStyle,
            editStyle: editStyle,
            useAmbientSoundtrack: useAmbientSoundtrack,
            revision: revision ?? 0,
            syncState: syncState ?? .localOnly,
            syncEnabled: syncEnabled ?? false,
            recoveredFromProjectId: recoveredFromProjectId,
            createdAt: createdAt,
            completedAt: completedAt,
            title: title
        )
    }
}
