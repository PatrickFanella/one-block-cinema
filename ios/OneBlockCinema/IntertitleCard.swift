import Foundation

nonisolated struct IntertitleCard: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    var text: String
    var duration: TimeInterval
    var position: Int

    init(
        id: UUID = UUID(),
        text: String,
        duration: TimeInterval = 2,
        position: Int
    ) {
        self.id = id
        self.text = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(120))
        self.duration = min(max(duration, 0.5), 5)
        self.position = max(0, position)
    }
}
