import Foundation

nonisolated enum ClipMediaStatus: String, Codable, Sendable, Hashable {
    case available
    case missing
    case importing
}

nonisolated struct FilmClip: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let promptId: UUID
    let fileURL: URL
    let thumbnailURL: URL?
    let duration: TimeInterval
    let createdAt: Date
    var showTitle: Bool
    var titleText: String
    var mediaStatus: ClipMediaStatus

    init(
        id: UUID = UUID(),
        promptId: UUID,
        fileURL: URL,
        thumbnailURL: URL? = nil,
        duration: TimeInterval = 0,
        createdAt: Date = Date(),
        showTitle: Bool = true,
        titleText: String = "",
        mediaStatus: ClipMediaStatus = .available
    ) {
        self.id = id
        self.promptId = promptId
        self.fileURL = fileURL
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.createdAt = createdAt
        self.showTitle = showTitle
        self.titleText = titleText
        self.mediaStatus = mediaStatus
    }

    var isMediaAvailable: Bool {
        mediaStatus == .available
    }

    enum CodingKeys: String, CodingKey {
        case id
        case promptId
        case fileURL
        case thumbnailURL
        case duration
        case createdAt
        case showTitle
        case titleText
        case mediaStatus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        promptId = try container.decode(UUID.self, forKey: .promptId)
        fileURL = try container.decode(URL.self, forKey: .fileURL)
        thumbnailURL = try container.decodeIfPresent(URL.self, forKey: .thumbnailURL)
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 0
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        showTitle = try container.decodeIfPresent(Bool.self, forKey: .showTitle) ?? true
        titleText = try container.decodeIfPresent(String.self, forKey: .titleText) ?? ""
        mediaStatus = try container.decodeIfPresent(ClipMediaStatus.self, forKey: .mediaStatus) ?? .available
    }
}
