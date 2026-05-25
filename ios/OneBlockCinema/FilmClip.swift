import Foundation

nonisolated struct FilmClip: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let promptId: UUID
    let fileURL: URL
    let thumbnailURL: URL?
    let duration: TimeInterval
    let createdAt: Date
    var showTitle: Bool
    var titleText: String

    init(
        id: UUID = UUID(),
        promptId: UUID,
        fileURL: URL,
        thumbnailURL: URL? = nil,
        duration: TimeInterval = 0,
        createdAt: Date = Date(),
        showTitle: Bool = true,
        titleText: String = ""
    ) {
        self.id = id
        self.promptId = promptId
        self.fileURL = fileURL
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.createdAt = createdAt
        self.showTitle = showTitle
        self.titleText = titleText
    }
}
