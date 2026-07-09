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
    var audioTracks: [ProjectAudioTrack]
    var intertitles: [IntertitleCard]
    var clipOrder: [UUID]
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
        audioTracks: [ProjectAudioTrack] = [],
        intertitles: [IntertitleCard] = [],
        clipOrder: [UUID] = [],
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
        self.audioTracks = audioTracks
        self.intertitles = intertitles
        self.clipOrder = clipOrder
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
        case audioTracks
        case intertitles
        case clipOrder
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
        audioTracks = try container.decodeIfPresent([ProjectAudioTrack].self, forKey: .audioTracks) ?? []
        intertitles = try container.decodeIfPresent([IntertitleCard].self, forKey: .intertitles) ?? []
        clipOrder = try container.decodeIfPresent([UUID].self, forKey: .clipOrder) ?? []
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

    func audioTrack(kind: ProjectAudioTrackKind) -> ProjectAudioTrack? {
        audioTracks.first { $0.kind == kind }
    }

    mutating func setAudioTrack(_ track: ProjectAudioTrack) {
        audioTracks.removeAll { $0.kind == track.kind }
        audioTracks.append(track)
    }

    mutating func removeAudioTrack(kind: ProjectAudioTrackKind) {
        audioTracks.removeAll { $0.kind == kind }
    }

    mutating func setAudioTrackVolume(kind: ProjectAudioTrackKind, volume: Double) {
        guard let index = audioTracks.firstIndex(where: { $0.kind == kind }) else { return }
        audioTracks[index].volume = min(max(volume, 0), 1)
    }

    mutating func addIntertitle(_ card: IntertitleCard) {
        intertitles.append(card)
        normalizeIntertitles()
    }

    mutating func updateIntertitle(_ card: IntertitleCard) {
        guard let index = intertitles.firstIndex(where: { $0.id == card.id }) else { return }
        intertitles[index] = card
        normalizeIntertitles()
    }

    mutating func removeIntertitle(id: UUID) {
        intertitles.removeAll { $0.id == id }
    }

    mutating func attachClip(_ clip: FilmClip) -> Bool {
        guard let promptIndex = prompts.firstIndex(where: { $0.id == clip.promptId }) else {
            return false
        }

        if let clipIndex = clips.firstIndex(where: { $0.promptId == clip.promptId }) {
            let replacedId = clips[clipIndex].id
            clips[clipIndex] = clip
            if let orderIndex = clipOrder.firstIndex(of: replacedId) {
                clipOrder[orderIndex] = clip.id
            }
        } else {
            clips.append(clip)
            if !clipOrder.isEmpty {
                clipOrder.append(clip.id)
            }
        }

        prompts[promptIndex].isCompleted = true
        sortClipsByPromptOrder()
        return true
    }

    mutating func removeClip(_ clip: FilmClip) {
        clips.removeAll { $0.id == clip.id }
        clipOrder.removeAll { $0 == clip.id }

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

    var missingClipCount: Int {
        clips.filter { $0.mediaStatus == .missing }.count
    }

    var missingAudioTrackCount: Int {
        audioTracks.filter { !FileManager.default.fileExists(atPath: $0.fileURL.path) }.count
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
            audioTracks: audioTracks,
            intertitles: intertitles,
            clipOrder: clipOrder,
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
        guard clipOrder.isEmpty else { return }
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

    var clipsInEditOrder: [FilmClip] {
        guard !clipOrder.isEmpty else { return clipsInPromptOrder }
        let positions = Dictionary(
            clipOrder.enumerated().map { ($0.element, $0.offset) },
            uniquingKeysWith: { first, _ in first }
        )
        return clips.sorted { lhs, rhs in
            let lhsPosition = positions[lhs.id] ?? Int.max
            let rhsPosition = positions[rhs.id] ?? Int.max
            if lhsPosition == rhsPosition {
                return lhs.createdAt < rhs.createdAt
            }
            return lhsPosition < rhsPosition
        }
    }

    mutating func setClipOrder(_ orderedClipIds: [UUID]) {
        let currentIds = Set(clips.map(\.id))
        var seenIds = Set<UUID>()
        let requestedIds = orderedClipIds.filter { currentIds.contains($0) && seenIds.insert($0).inserted }
        let missingIds = clipsInPromptOrder.map(\.id).filter { !requestedIds.contains($0) }
        clipOrder = requestedIds + missingIds
    }

    private mutating func normalizeIntertitles() {
        let maximumPosition = clips.count
        intertitles = intertitles
            .map { card in
                IntertitleCard(
                    id: card.id,
                    text: card.text,
                    duration: card.duration,
                    position: min(card.position, maximumPosition)
                )
            }
            .filter { !$0.text.isEmpty }
            .sorted {
                $0.position == $1.position
                    ? $0.id.uuidString < $1.id.uuidString
                    : $0.position < $1.position
            }
    }
}
