import Foundation

nonisolated enum EditStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case standard
    case silentFilm = "silent_film"
    case voiceoverDiary = "voiceover_diary"

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .standard: "Standard"
        case .silentFilm: "Silent Film"
        case .voiceoverDiary: "Voiceover Diary"
        }
    }

    var icon: String {
        switch self {
        case .standard: "film"
        case .silentFilm: "theatermask.and.paintbrush"
        case .voiceoverDiary: "mic.fill"
        }
    }

    var description: String {
        switch self {
        case .standard: "Clean modern edit"
        case .silentFilm: "Sepia tones & intertitles"
        case .voiceoverDiary: "Narration-style pacing"
        }
    }
}
