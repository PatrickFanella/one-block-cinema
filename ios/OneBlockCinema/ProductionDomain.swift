import Foundation

// The current creator models are the first production schema. These aliases let
// repositories use product language while existing feature views migrate in slices.
typealias FilmProject = FilmSession
typealias ProjectShot = ShotPrompt
typealias MediaAsset = FilmClip

nonisolated enum SyncState: String, Codable, Sendable, Hashable {
    case localOnly = "local_only"
    case pending
    case syncing
    case synced
    case conflict
    case failed
}

nonisolated enum SyncOperationKind: String, Codable, Sendable, Hashable {
    case projectUpsert = "project_upsert"
    case projectDelete = "project_delete"
    case mediaUpload = "media_upload"
    case mediaDelete = "media_delete"
}

nonisolated enum SyncOperationState: String, Codable, Sendable, Hashable {
    case pending
    case processing
    case failed
    case completed
}

nonisolated struct SyncOutboxOperation: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let aggregateId: UUID
    let kind: SyncOperationKind
    let payload: Data
    let createdAt: Date
    let attemptCount: Int
    let nextAttemptAt: Date?
    let state: SyncOperationState
    let lastError: String?
}

nonisolated enum TransitionStyle: String, Codable, Sendable, Hashable {
    case cut
    case crossfade
}

nonisolated struct ClipTrim: Codable, Sendable, Hashable {
    let sourceStart: TimeInterval
    let duration: TimeInterval
}

nonisolated struct EditDecision: Codable, Sendable, Hashable {
    var assetOrder: [UUID]
    var trims: [UUID: ClipTrim]
    var transitions: [UUID: TransitionStyle]
    var titles: [UUID: String]
    var trackVolumes: [UUID: Double]
    var pacingStyle: PacingStyle
    var editStyle: EditStyle

    init(
        assetOrder: [UUID] = [],
        trims: [UUID: ClipTrim] = [:],
        transitions: [UUID: TransitionStyle] = [:],
        titles: [UUID: String] = [:],
        trackVolumes: [UUID: Double] = [:],
        pacingStyle: PacingStyle = .rhythmic,
        editStyle: EditStyle = .standard
    ) {
        self.assetOrder = assetOrder
        self.trims = trims
        self.transitions = transitions
        self.titles = titles
        self.trackVolumes = trackVolumes
        self.pacingStyle = pacingStyle
        self.editStyle = editStyle
    }
}

nonisolated struct SyncConflictResolution: Sendable {
    let canonicalProject: FilmProject
    let recoveredLocalCopy: FilmProject
}

nonisolated enum SyncConflictResolver {
    static func preserveBoth(local: FilmProject, server: FilmProject) -> SyncConflictResolution {
        var canonical = server
        canonical.syncState = .synced
        return SyncConflictResolution(
            canonicalProject: canonical,
            recoveredLocalCopy: local.recoveredCopy()
        )
    }
}

nonisolated enum PublicationVisibility: String, Codable, Sendable, Hashable {
    case privateDraft = "private"
    case unlisted
    case publicChallenge = "public"
}

nonisolated enum PublicationStatus: String, Codable, Sendable, Hashable {
    case draft
    case uploading
    case processing
    case pendingReview = "pending_review"
    case approved
    case rejected
    case removed
}

nonisolated struct Publication: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let projectId: UUID
    let ownerId: UUID
    var challengeId: UUID?
    var visibility: PublicationVisibility
    var status: PublicationStatus
    var caption: String
    var commentsEnabled: Bool
    var playbackId: String?
    let createdAt: Date
    var updatedAt: Date
}

nonisolated enum ChallengeCadence: String, Codable, Sendable, Hashable {
    case daily
    case weekly
}

nonisolated struct Challenge: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let title: String
    let prompt: String
    let templateId: String
    let cadence: ChallengeCadence
    let startsAt: Date
    let endsAt: Date
}

nonisolated struct Comment: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let publicationId: UUID
    let authorId: UUID
    let body: String
    let feedbackPromptId: String?
    let createdAt: Date
    var deletedAt: Date?
}

nonisolated enum ReportReason: String, Codable, Sendable, Hashable {
    case harassment
    case hate
    case sexualContent = "sexual_content"
    case violence
    case selfHarm = "self_harm"
    case privacy
    case spam
    case other
}

nonisolated struct Report: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let reporterId: UUID
    let publicationId: UUID?
    let commentId: UUID?
    let reason: ReportReason
    let createdAt: Date
}

nonisolated struct CritiqueScore: Codable, Sendable, Hashable {
    let score: Int
    let note: String
}

nonisolated struct CritiqueImprovement: Codable, Sendable, Hashable {
    let timestampSeconds: TimeInterval
    let suggestion: String
}

nonisolated struct CritiqueResult: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let projectId: UUID
    let storyClarity: CritiqueScore
    let framing: CritiqueScore
    let pacing: CritiqueScore
    let audio: CritiqueScore
    let continuity: CritiqueScore
    let strengths: [String]
    let improvements: [CritiqueImprovement]
    let nextExercise: String
    let createdAt: Date
}
