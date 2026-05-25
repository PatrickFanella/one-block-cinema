import Foundation

nonisolated struct ShotPrompt: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    let index: Int
    let direction: String
    let hint: String
    let icon: String
    var isCompleted: Bool

    init(id: UUID = UUID(), index: Int, direction: String, hint: String, icon: String, isCompleted: Bool = false) {
        self.id = id
        self.index = index
        self.direction = direction
        self.hint = hint
        self.icon = icon
        self.isCompleted = isCompleted
    }
}
