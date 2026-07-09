import Foundation

nonisolated struct FilmSession: Identifiable, Codable, Sendable {
    let id: UUID
    let theme: FilmTheme
    let templateId: String?
    let templateSchemaVersion: Int?
    let templateTitle: String?
    let templateOutcome: String?
    let aspectRatio: TemplateAspectRatio?
    let durationTarget: TemplateDurationTarget?
    let assemblyGuidance: TemplateAssemblyGuidance?
    var prompts: [ShotPrompt]
    var clips: [FilmClip]
    var pacingStyle: PacingStyle
    var editStyle: EditStyle
    var useAmbientSoundtrack: Bool
    var revision: Int
    var syncState: SyncState
    var syncEnabled: Bool
    var recoveredFromProjectId: UUID?
    let createdAt: Date
    var completedAt: Date?
    var title: String

    init(
        id: UUID = UUID(),
        theme: FilmTheme,
        templateId: String? = nil,
        templateSchemaVersion: Int? = nil,
        templateTitle: String? = nil,
        templateOutcome: String? = nil,
        aspectRatio: TemplateAspectRatio? = nil,
        durationTarget: TemplateDurationTarget? = nil,
        assemblyGuidance: TemplateAssemblyGuidance? = nil,
        prompts: [ShotPrompt] = [],
        clips: [FilmClip] = [],
        pacingStyle: PacingStyle = .rhythmic,
        editStyle: EditStyle = .standard,
        useAmbientSoundtrack: Bool = false,
        revision: Int = 0,
        syncState: SyncState = .localOnly,
        syncEnabled: Bool = false,
        recoveredFromProjectId: UUID? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        title: String = ""
    ) {
        self.id = id
        self.theme = theme
        self.templateId = templateId
        self.templateSchemaVersion = templateSchemaVersion
        self.templateTitle = templateTitle
        self.templateOutcome = templateOutcome
        self.aspectRatio = aspectRatio
        self.durationTarget = durationTarget
        self.assemblyGuidance = assemblyGuidance
        self.prompts = prompts
        self.clips = clips
        self.pacingStyle = pacingStyle
        self.editStyle = editStyle
        self.useAmbientSoundtrack = useAmbientSoundtrack
        self.revision = revision
        self.syncState = syncState
        self.syncEnabled = syncEnabled
        self.recoveredFromProjectId = recoveredFromProjectId
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.title = title
    }

    enum CodingKeys: String, CodingKey {
        case id
        case theme
        case templateId
        case templateSchemaVersion
        case templateTitle
        case templateOutcome
        case aspectRatio
        case durationTarget
        case assemblyGuidance
        case prompts
        case clips
        case pacingStyle
        case editStyle
        case useAmbientSoundtrack
        case revision
        case syncState
        case syncEnabled
        case recoveredFromProjectId
        case createdAt
        case completedAt
        case title
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        theme = try container.decode(FilmTheme.self, forKey: .theme)
        templateId = try container.decodeIfPresent(String.self, forKey: .templateId)
        templateSchemaVersion = try container.decodeIfPresent(Int.self, forKey: .templateSchemaVersion)
        templateTitle = try container.decodeIfPresent(String.self, forKey: .templateTitle)
        templateOutcome = try container.decodeIfPresent(String.self, forKey: .templateOutcome)
        aspectRatio = try container.decodeIfPresent(TemplateAspectRatio.self, forKey: .aspectRatio)
        durationTarget = try container.decodeIfPresent(TemplateDurationTarget.self, forKey: .durationTarget)
        assemblyGuidance = try container.decodeIfPresent(TemplateAssemblyGuidance.self, forKey: .assemblyGuidance)
        prompts = try container.decodeIfPresent([ShotPrompt].self, forKey: .prompts) ?? []
        clips = try container.decodeIfPresent([FilmClip].self, forKey: .clips) ?? []
        pacingStyle = try container.decodeIfPresent(PacingStyle.self, forKey: .pacingStyle) ?? .rhythmic
        editStyle = try container.decodeIfPresent(EditStyle.self, forKey: .editStyle) ?? .standard
        useAmbientSoundtrack = try container.decodeIfPresent(Bool.self, forKey: .useAmbientSoundtrack) ?? false
        revision = try container.decodeIfPresent(Int.self, forKey: .revision) ?? 0
        syncState = try container.decodeIfPresent(SyncState.self, forKey: .syncState) ?? .localOnly
        syncEnabled = try container.decodeIfPresent(Bool.self, forKey: .syncEnabled) ?? false
        recoveredFromProjectId = try container.decodeIfPresent(UUID.self, forKey: .recoveredFromProjectId)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Untitled Film"
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

    func recoveredCopy(at date: Date = Date()) -> FilmSession {
        FilmSession(
            theme: theme,
            templateId: templateId,
            templateSchemaVersion: templateSchemaVersion,
            templateTitle: templateTitle,
            templateOutcome: templateOutcome,
            aspectRatio: aspectRatio,
            durationTarget: durationTarget,
            assemblyGuidance: assemblyGuidance,
            prompts: prompts,
            clips: clips,
            pacingStyle: pacingStyle,
            editStyle: editStyle,
            useAmbientSoundtrack: useAmbientSoundtrack,
            revision: 0,
            syncState: .localOnly,
            syncEnabled: false,
            recoveredFromProjectId: id,
            createdAt: date,
            title: "\(title) — Recovered Copy"
        )
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
