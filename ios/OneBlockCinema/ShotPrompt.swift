import Foundation

nonisolated struct ShotPrompt: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let templateShotId: String?
    let index: Int
    let direction: String
    let hint: String
    let icon: String
    let targetSeconds: Int?
    var isCompleted: Bool

    init(
        id: UUID = UUID(),
        templateShotId: String? = nil,
        index: Int,
        direction: String,
        hint: String,
        icon: String,
        targetSeconds: Int? = nil,
        isCompleted: Bool = false
    ) {
        self.id = id
        self.templateShotId = templateShotId
        self.index = index
        self.direction = direction
        self.hint = hint
        self.icon = icon
        self.targetSeconds = targetSeconds
        self.isCompleted = isCompleted
    }
}
