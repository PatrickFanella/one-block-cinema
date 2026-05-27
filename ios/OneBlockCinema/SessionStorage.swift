import Foundation

actor SessionStorage {
    private let userDefaults: UserDefaults
    private let sessionsKey: String

    init(
        userDefaults: UserDefaults = .standard,
        sessionsKey: String = "saved_film_sessions"
    ) {
        self.userDefaults = userDefaults
        self.sessionsKey = sessionsKey
    }

    func saveSessions(_ sessions: [FilmSession]) {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        userDefaults.set(data, forKey: sessionsKey)
    }

    func loadSessions() -> [FilmSession] {
        guard let data = userDefaults.data(forKey: sessionsKey),
              let sessions = try? JSONDecoder().decode([FilmSession].self, from: data) else {
            return []
        }
        return sessions
    }
}
