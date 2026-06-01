import Foundation

actor SessionStorage {
    private let userDefaults: UserDefaults
    private let sessionsKey: String
    private let fileManager: FileManager

    init(
        userDefaults: UserDefaults = .standard,
        sessionsKey: String = "saved_film_sessions",
        fileManager: FileManager = .default
    ) {
        self.userDefaults = userDefaults
        self.sessionsKey = sessionsKey
        self.fileManager = fileManager
    }

    private var rootDirectory: URL {
        get throws {
            let base = try fileManager.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            return base.appendingPathComponent("OneBlockCinema", isDirectory: true)
        }
    }

    private var sessionsFile: URL {
        get throws { try rootDirectory.appendingPathComponent("sessions.json") }
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

    func saveSessions(_ sessions: [FilmSession]) throws {
        try ensureDirectory(try rootDirectory)
        let data = try JSONEncoder().encode(sessions)
        try data.write(to: try sessionsFile, options: [.atomic])
        userDefaults.set(data, forKey: sessionsKey)
    }

    func loadSessions() throws -> [FilmSession] {
        if let data = try? Data(contentsOf: try sessionsFile) {
            return try JSONDecoder().decode([FilmSession].self, from: data)
        }

        guard let data = userDefaults.data(forKey: sessionsKey) else {
            return []
        }

        let sessions = try JSONDecoder().decode([FilmSession].self, from: data)
        try saveSessions(sessions)
        return sessions
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
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    func deleteDraft(for sessionId: UUID) throws {
        let directory = try draftDirectory(for: sessionId)
        guard fileManager.fileExists(atPath: directory.path) else { return }
        try fileManager.removeItem(at: directory)
    }
}
