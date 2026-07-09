import Foundation
@testable import OneBlockCinema
import Testing

struct IntertitleTests {
    private func makeClip(_ number: Int, duration: TimeInterval) -> FilmClip {
        FilmClip(
            promptId: UUID(),
            fileURL: URL(fileURLWithPath: "/tmp/intertitle-clip-\(number).mov"),
            duration: duration
        )
    }

    private func makeStorage() -> SessionStorage {
        let suiteName = "IntertitleTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("IntertitleTests-\(UUID().uuidString)", isDirectory: true)
        return SessionStorage(userDefaults: userDefaults, rootDirectory: root)
    }

    @Test func persistsStandaloneIntertitleEditDecisions() async throws {
        let storage = makeStorage()
        let card = IntertitleCard(text: "Three hours later", duration: 2.5, position: 1)
        let session = FilmSession(
            theme: .noir,
            intertitles: [card],
            title: "Intertitle draft"
        )

        try await storage.saveSessions([session])
        let loaded = try #require(try await storage.loadSessions().first)

        #expect(loaded.intertitles == [card])
    }

    @Test func intertitleOccupiesTimelineAndPreventsCrossfadeAcrossCard() {
        let first = makeClip(1, duration: 4)
        var second = makeClip(2, duration: 4)
        second.transitionStyle = .crossfade
        let card = IntertitleCard(text: "Meanwhile", duration: 2, position: 1)
        let project = FilmSession(
            theme: .noir,
            clips: [first, second],
            intertitles: [card]
        )

        let plan = VideoExportLimits.plan(for: project)

        #expect(plan.segments.map(\.timelineStart) == [0, 6])
        #expect(plan.segments.map(\.transitionDuration) == [0, 0])
        #expect(plan.intertitleCues == [
            RenderIntertitleCue(id: card.id, text: "Meanwhile", timelineStart: 4, duration: 2)
        ])
        #expect(plan.totalDuration == 10)
    }

    @Test func removesIntertitleByStableIdentifier() {
        let retained = IntertitleCard(text: "Keep", position: 0)
        let removed = IntertitleCard(text: "Remove", position: 1)
        var project = FilmSession(theme: .noir, intertitles: [retained, removed])

        project.removeIntertitle(id: removed.id)

        #expect(project.intertitles == [retained])
    }

    @Test func intertitleRespectsMaximumDurationBoundary() {
        let clip = makeClip(1, duration: 179)
        let card = IntertitleCard(text: "The end", duration: 3, position: 1)
        let project = FilmSession(theme: .documentary, clips: [clip], intertitles: [card])

        let plan = VideoExportLimits.plan(for: project)

        #expect(plan.intertitleCues.first?.duration == 1)
        #expect(plan.totalDuration == 180)
        #expect(plan.wasTrimmedToMaximumDuration)
    }
}
