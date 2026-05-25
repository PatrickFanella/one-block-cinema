import Foundation

nonisolated enum PacingStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case quickCuts = "quick_cuts"
    case slowCinema = "slow_cinema"
    case rhythmic = "rhythmic"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .quickCuts: "Quick Cuts"
        case .slowCinema: "Slow Cinema"
        case .rhythmic: "Rhythmic"
        }
    }

    var icon: String {
        switch self {
        case .quickCuts: "bolt.fill"
        case .slowCinema: "tortoise.fill"
        case .rhythmic: "metronome.fill"
        }
    }

    var description: String {
        switch self {
        case .quickCuts: "Fast-paced, punchy transitions"
        case .slowCinema: "Long holds, gentle fades"
        case .rhythmic: "Steady, musical pacing"
        }
    }

    var transitionDuration: TimeInterval {
        switch self {
        case .quickCuts: 0.3
        case .slowCinema: 1.5
        case .rhythmic: 0.8
        }
    }
}
