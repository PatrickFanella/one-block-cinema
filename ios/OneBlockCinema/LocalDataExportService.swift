import Foundation

nonisolated struct LocalDataExportDocument: Codable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let exportedAt: Date
    let scope: String
    let mediaIncluded: Bool
    let projects: [LocalDataExportProject]
    let recoveryIssues: [DraftRecoveryIssue]

    init(
        sessions: [FilmSession],
        recoveryIssues: [DraftRecoveryIssue],
        exportedAt: Date
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.exportedAt = exportedAt
        scope = "local_device_metadata"
        mediaIncluded = false
        projects = sessions.map(LocalDataExportProject.init)
        self.recoveryIssues = recoveryIssues
    }
}

nonisolated struct LocalDataExportProject: Codable, Sendable {
    let id: UUID
    let title: String
    let theme: String
    let templateId: String?
    let templateSchemaVersion: Int?
    let templateTitle: String?
    let templateOutcome: String?
    let aspectRatio: String?
    let durationTarget: TemplateDurationTarget?
    let assemblyGuidance: TemplateAssemblyGuidance?
    let prompts: [ShotPrompt]
    let clips: [LocalDataExportClip]
    let audioTracks: [LocalDataExportAudioTrack]
    let intertitles: [IntertitleCard]
    let clipOrder: [UUID]
    let pacingStyle: String
    let editStyle: String
    let useAmbientSoundtrack: Bool
    let revision: Int
    let syncState: String
    let syncEnabled: Bool
    let recoveredFromProjectId: UUID?
    let createdAt: Date
    let completedAt: Date?

    init(_ session: FilmSession) {
        id = session.id
        title = session.title
        theme = session.theme.rawValue
        templateId = session.templateId
        templateSchemaVersion = session.templateSchemaVersion
        templateTitle = session.templateTitle
        templateOutcome = session.templateOutcome
        aspectRatio = session.aspectRatio?.rawValue
        durationTarget = session.durationTarget
        assemblyGuidance = session.assemblyGuidance
        prompts = session.prompts
        clips = session.clips.map(LocalDataExportClip.init)
        audioTracks = session.audioTracks.map(LocalDataExportAudioTrack.init)
        intertitles = session.intertitles
        clipOrder = session.clipOrder
        pacingStyle = session.pacingStyle.rawValue
        editStyle = session.editStyle.rawValue
        useAmbientSoundtrack = session.useAmbientSoundtrack
        revision = session.revision
        syncState = session.syncState.rawValue
        syncEnabled = session.syncEnabled
        recoveredFromProjectId = session.recoveredFromProjectId
        createdAt = session.createdAt
        completedAt = session.completedAt
    }
}

nonisolated struct LocalDataExportClip: Codable, Sendable {
    let id: UUID
    let promptId: UUID
    let fileName: String
    let thumbnailFileName: String?
    let duration: TimeInterval
    let createdAt: Date
    let showTitle: Bool
    let titleText: String
    let mediaStatus: ClipMediaStatus
    let trimStart: TimeInterval
    let trimEnd: TimeInterval?
    let volume: Double
    let transitionStyle: TransitionStyle

    init(_ clip: FilmClip) {
        id = clip.id
        promptId = clip.promptId
        fileName = clip.fileURL.lastPathComponent
        thumbnailFileName = clip.thumbnailURL?.lastPathComponent
        duration = clip.duration
        createdAt = clip.createdAt
        showTitle = clip.showTitle
        titleText = clip.titleText
        mediaStatus = clip.mediaStatus
        trimStart = clip.trimStart
        trimEnd = clip.trimEnd
        volume = clip.volume
        transitionStyle = clip.transitionStyle
    }
}

nonisolated struct LocalDataExportAudioTrack: Codable, Sendable {
    let id: UUID
    let kind: ProjectAudioTrackKind
    let fileName: String
    let duration: TimeInterval
    let volume: Double
    let isAvailable: Bool

    init(_ track: ProjectAudioTrack) {
        id = track.id
        kind = track.kind
        fileName = track.fileURL.lastPathComponent
        duration = track.duration
        volume = track.volume
        isAvailable = FileManager.default.fileExists(atPath: track.fileURL.path)
    }
}

actor LocalDataExportService {
    private let fileManager: FileManager
    private let outputDirectory: URL

    init(
        fileManager: FileManager = .default,
        outputDirectory: URL = FileManager.default.temporaryDirectory
    ) {
        self.fileManager = fileManager
        self.outputDirectory = outputDirectory
    }

    func export(
        sessions: [FilmSession],
        recoveryIssues: [DraftRecoveryIssue],
        exportedAt: Date = Date()
    ) throws -> URL {
        try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        let document = LocalDataExportDocument(
            sessions: sessions,
            recoveryIssues: recoveryIssues,
            exportedAt: exportedAt
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(document)
        let destination = outputDirectory.appendingPathComponent(
            "one-block-cinema-data-\(Self.fileTimestamp(exportedAt)).json"
        )
        try data.write(to: destination, options: .atomic)
        return destination
    }

    private static func fileTimestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
            .replacingOccurrences(of: ":", with: "-")
    }
}
