import Foundation

nonisolated struct FilmSession: Identifiable, Codable, Sendable {
    let id: UUID
    let theme: FilmTheme
    var prompts: [ShotPrompt]
    var clips: [FilmClip]
    var pacingStyle: PacingStyle
    var editStyle: EditStyle
    var useAmbientSoundtrack: Bool
    let createdAt: Date
    var completedAt: Date?
    var title: String

    init(
        id: UUID = UUID(),
        theme: FilmTheme,
        prompts: [ShotPrompt] = [],
        clips: [FilmClip] = [],
        pacingStyle: PacingStyle = .rhythmic,
        editStyle: EditStyle = .standard,
        useAmbientSoundtrack: Bool = false,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        title: String = ""
    ) {
        self.id = id
        self.theme = theme
        self.prompts = prompts
        self.clips = clips
        self.pacingStyle = pacingStyle
        self.editStyle = editStyle
        self.useAmbientSoundtrack = useAmbientSoundtrack
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.title = title
    }

    var isComplete: Bool {
        !clips.isEmpty && prompts.allSatisfy(\.isCompleted)
    }

    var completedPromptCount: Int {
        prompts.filter(\.isCompleted).count
    }

    var progress: Double {
        guard !prompts.isEmpty else { return 0 }
        return Double(completedPromptCount) / Double(prompts.count)
    }

    var clipsInPromptOrder: [FilmClip] {
        let promptPositions = Dictionary(uniqueKeysWithValues: prompts.map { ($0.id, $0.index) })

        return clips.sorted { lhs, rhs in
            let lhsPosition = promptPositions[lhs.promptId] ?? Int.max
            let rhsPosition = promptPositions[rhs.promptId] ?? Int.max

            if lhsPosition == rhsPosition {
                return lhs.createdAt < rhs.createdAt
            }

            return lhsPosition < rhsPosition
        }
    }
}
