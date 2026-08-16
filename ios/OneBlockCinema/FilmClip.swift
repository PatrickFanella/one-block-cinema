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
    var trimStart: TimeInterval
    var trimEnd: TimeInterval?
    var volume: Double
    var transitionStyle: TransitionStyle

    init(
        id: UUID = UUID(),
        promptId: UUID,
        fileURL: URL,
        thumbnailURL: URL? = nil,
        duration: TimeInterval = 0,
        createdAt: Date = Date(),
        showTitle: Bool = true,
        titleText: String = "",
        mediaStatus: ClipMediaStatus = .available,
        trimStart: TimeInterval = 0,
        trimEnd: TimeInterval? = nil,
        volume: Double = 1,
        transitionStyle: TransitionStyle = .cut
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
        self.trimStart = trimStart
        self.trimEnd = trimEnd
        self.volume = volume
        self.transitionStyle = transitionStyle
    }

    var isMediaAvailable: Bool {
        mediaStatus == .available
    }

    var effectiveTrimStart: TimeInterval {
        min(max(trimStart, 0), max(duration, 0))
    }

    var effectiveTrimEnd: TimeInterval {
        min(max(trimEnd ?? duration, effectiveTrimStart), max(duration, 0))
    }

    var trimmedDuration: TimeInterval {
        max(0, effectiveTrimEnd - effectiveTrimStart)
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
        case trimStart
        case trimEnd
        case volume
        case transitionStyle
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
        trimStart = try container.decodeIfPresent(TimeInterval.self, forKey: .trimStart) ?? 0
        trimEnd = try container.decodeIfPresent(TimeInterval.self, forKey: .trimEnd)
        volume = try container.decodeIfPresent(Double.self, forKey: .volume) ?? 1
        transitionStyle = try container.decodeIfPresent(TransitionStyle.self, forKey: .transitionStyle) ?? .cut
    }
}
