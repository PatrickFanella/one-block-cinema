import Foundation
@testable import OneBlockCinema
import Testing

struct LocalDataDeletionTests {
    @Test func deletesProjectsMediaRecoveryRecordsAndPendingOperations() async throws {
        let suiteName = "LocalDataDeletionTests.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults.set(Data("unreadable legacy data".utf8), forKey: "saved_film_sessions")
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalDataDeletionTests-\(UUID().uuidString)", isDirectory: true)
        let storage = SessionStorage(userDefaults: userDefaults, rootDirectory: root)

        _ = try await storage.loadSessions()
        #expect(try await !(storage.loadRecoveryIssues()).isEmpty)

        let session = FilmSession(theme: .documentary, title: "Delete me")
        let source = root.appendingPathComponent("source.mov")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("fixture".utf8).write(to: source)
        let copiedMedia = try await storage.copyClip(source, for: session.id)
        try await storage.saveSessions([session])
        _ = try await storage.enqueueSyncOperation(
            aggregateId: session.id,
            kind: .projectUpsert,
            payload: Data("{}".utf8),
            idempotencyKey: UUID()
        )

        try await storage.deleteAllLocalData()

        #expect(try await (storage.loadSessions()).isEmpty)
        #expect(try await (storage.loadRecoveryIssues()).isEmpty)
        #expect(try await (storage.loadPendingSyncOperations()).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: copiedMedia.path))
        #expect(userDefaults.data(forKey: "saved_film_sessions") == nil)
    }
}
