import Foundation
import GRDB

nonisolated struct InterruptedRender: Identifiable, Sendable, Hashable {
    let id: UUID
    let projectId: UUID
    let startedAt: Date
}

extension SessionStorage {
    func beginRender(id: UUID, projectId: UUID, at date: Date = Date()) throws {
        let queue = try database()
        try queue.write { db in
            try db.execute(
                sql: """
                    INSERT INTO local_render_jobs (
                        id, session_id, status, started_at, updated_at, failure_reason
                    ) VALUES (?, ?, 'rendering', ?, ?, NULL)
                    ON CONFLICT(session_id) DO UPDATE SET
                        id = excluded.id,
                        status = 'rendering',
                        started_at = excluded.started_at,
                        updated_at = excluded.updated_at,
                        failure_reason = NULL
                    """,
                arguments: [
                    id.uuidString,
                    projectId.uuidString,
                    date.timeIntervalSince1970,
                    date.timeIntervalSince1970,
                ]
            )
        }
    }

    func markRenderCompleted(id: UUID, at date: Date = Date()) throws {
        try updateRender(id: id, status: "completed", reason: nil, at: date)
    }

    func markRenderCancelled(id: UUID, at date: Date = Date()) throws {
        try updateRender(id: id, status: "cancelled", reason: nil, at: date)
    }

    func markRenderFailed(id: UUID, reason: String, at date: Date = Date()) throws {
        try updateRender(id: id, status: "failed", reason: reason, at: date)
    }

    func markRenderInterrupted(id: UUID, reason: String, at date: Date = Date()) throws {
        try updateRender(id: id, status: "interrupted", reason: reason, at: date)
    }

    func recoverInterruptedRenders(at date: Date = Date()) throws -> [InterruptedRender] {
        let queue = try database()
        return try queue.write { db in
            try db.execute(
                sql: """
                    UPDATE local_render_jobs
                    SET status = 'interrupted',
                        updated_at = ?,
                        failure_reason = 'app_terminated'
                    WHERE status = 'rendering'
                    """,
                arguments: [date.timeIntervalSince1970]
            )
            let rows = try Row.fetchAll(
                db,
                sql: """
                    SELECT id, session_id, started_at
                    FROM local_render_jobs
                    WHERE status = 'interrupted'
                    ORDER BY updated_at DESC
                    """
            )
            return rows.compactMap { row in
                guard let id = UUID(uuidString: row["id"]),
                      let projectId = UUID(uuidString: row["session_id"]) else { return nil }
                let startedAt: Double = row["started_at"]
                return InterruptedRender(
                    id: id,
                    projectId: projectId,
                    startedAt: Date(timeIntervalSince1970: startedAt)
                )
            }
        }
    }

    func dismissInterruptedRenders(at date: Date = Date()) throws {
        let queue = try database()
        try queue.write { db in
            try db.execute(
                sql: """
                    UPDATE local_render_jobs
                    SET status = 'dismissed', updated_at = ?
                    WHERE status = 'interrupted'
                    """,
                arguments: [date.timeIntervalSince1970]
            )
        }
    }

    private func updateRender(id: UUID, status: String, reason: String?, at date: Date) throws {
        let queue = try database()
        try queue.write { db in
            try db.execute(
                sql: """
                    UPDATE local_render_jobs
                    SET status = ?, updated_at = ?, failure_reason = ?
                    WHERE id = ?
                    """,
                arguments: [
                    status,
                    date.timeIntervalSince1970,
                    reason.map { String($0.prefix(200)) },
                    id.uuidString,
                ]
            )
        }
    }
}
