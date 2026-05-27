import Foundation

nonisolated struct FilmSession: Identifiable, Codable, Sendable {
    let id: UUID
    let theme: FilmTheme
    let templateId: String?
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
        templateId: String? = nil,
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
        self.templateId = templateId
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

    func clip(forPromptId promptId: UUID) -> FilmClip? {
        clips.first { $0.promptId == promptId }
    }

    mutating func attachClip(_ clip: FilmClip) -> Bool {
        guard let promptIndex = prompts.firstIndex(where: { $0.id == clip.promptId }) else {
            return false
        }

        if let clipIndex = clips.firstIndex(where: { $0.promptId == clip.promptId }) {
            clips[clipIndex] = clip
        } else {
            clips.append(clip)
        }

        prompts[promptIndex].isCompleted = true
        sortClipsByPromptOrder()
        return true
    }

    mutating func removeClip(_ clip: FilmClip) {
        clips.removeAll { $0.id == clip.id }

        if clips.contains(where: { $0.promptId == clip.promptId }) {
            return
        }

        if let promptIndex = prompts.firstIndex(where: { $0.id == clip.promptId }) {
            prompts[promptIndex].isCompleted = false
        }
    }

    var completedPromptCount: Int {
        prompts.filter(\.isCompleted).count
    }

    var progress: Double {
        guard !prompts.isEmpty else { return 0 }
        return Double(completedPromptCount) / Double(prompts.count)
    }

    private mutating func sortClipsByPromptOrder() {
        clips = clipsInPromptOrder
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
