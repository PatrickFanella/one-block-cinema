import Foundation

actor SessionStorage {
    private let sessionsKey = "saved_film_sessions"

    func saveSessions(_ sessions: [FilmSession]) {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        UserDefaults.standard.set(data, forKey: sessionsKey)
    }

    func loadSessions() -> [FilmSession] {
        guard let data = UserDefaults.standard.data(forKey: sessionsKey),
              let sessions = try? JSONDecoder().decode([FilmSession].self, from: data) else {
            return []
        }
        return sessions
    }
}
