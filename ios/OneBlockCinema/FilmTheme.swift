import SwiftUI

nonisolated enum FilmTheme: String, CaseIterable, Identifiable, Codable, Sendable {
    case noir
    case romance
    case documentary
    case horror
    case dream

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .noir: "Noir"
        case .romance: "Romance"
        case .documentary: "Documentary"
        case .horror: "Horror"
        case .dream: "Dream"
        }
    }

    var subtitle: String {
        switch self {
        case .noir: "Shadows & mystery"
        case .romance: "Tenderness & light"
        case .documentary: "Truth & observation"
        case .horror: "Dread & unease"
        case .dream: "Surreal & floating"
        }
    }

    var icon: String {
        switch self {
        case .noir: "moon.fill"
        case .romance: "heart.fill"
        case .documentary: "eye.fill"
        case .horror: "bolt.fill"
        case .dream: "cloud.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .noir: Color(red: 0.6, green: 0.65, blue: 0.75)
        case .romance: Color(red: 0.9, green: 0.45, blue: 0.5)
        case .documentary: Color(red: 0.85, green: 0.75, blue: 0.55)
        case .horror: Color(red: 0.7, green: 0.2, blue: 0.2)
        case .dream: Color(red: 0.6, green: 0.5, blue: 0.85)
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .noir: [Color(red: 0.08, green: 0.08, blue: 0.12), Color(red: 0.15, green: 0.15, blue: 0.22)]
        case .romance: [Color(red: 0.12, green: 0.06, blue: 0.08), Color(red: 0.22, green: 0.1, blue: 0.14)]
        case .documentary: [Color(red: 0.1, green: 0.09, blue: 0.06), Color(red: 0.2, green: 0.18, blue: 0.12)]
        case .horror: [Color(red: 0.1, green: 0.04, blue: 0.04), Color(red: 0.18, green: 0.06, blue: 0.06)]
        case .dream: [Color(red: 0.08, green: 0.06, blue: 0.14), Color(red: 0.14, green: 0.1, blue: 0.24)]
        }
    }
}
