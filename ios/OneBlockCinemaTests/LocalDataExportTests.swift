import Foundation
import Testing
@testable import OneBlockCinema

struct LocalDataExportTests {
    @Test func exportsEditableProjectMetadataWithoutPrivatePathsOrMediaBytes() async throws {
        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalDataExportTests-\(UUID().uuidString)", isDirectory: true)
        let service = LocalDataExportService(outputDirectory: outputDirectory)
        let prompt = ShotPrompt(index: 0, direction: "Wide", hint: "Hold steady", icon: "camera")
        let clip = FilmClip(
            promptId: prompt.id,
            fileURL: URL(fileURLWithPath: "/private/app-container/Drafts/secret-source.mov"),
            duration: 8,
            showTitle: true,
            titleText: "Opening",
            trimStart: 1,
            trimEnd: 6,
            volume: 0.75,
            transitionStyle: .crossfade
        )
        let card = IntertitleCard(text: "Later", duration: 2, position: 1)
        let project = FilmSession(
            theme: .documentary,
            prompts: [prompt],
            clips: [clip],
            intertitles: [card],
            clipOrder: [clip.id],
            title: "Export me"
        )
        let date = Date(timeIntervalSince1970: 1_700_000_000)

        let url = try await service.export(sessions: [project], recoveryIssues: [], exportedAt: date)
        let data = try Data(contentsOf: url)
        let json = try #require(String(data: data, encoding: .utf8))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(LocalDataExportDocument.self, from: data)

        #expect(document.schemaVersion == 1)
        #expect(document.scope == "local_device_metadata")
        #expect(!document.mediaIncluded)
        #expect(document.projects.first?.clips.first?.fileName == "secret-source.mov")
        #expect(document.projects.first?.clips.first?.trimStart == 1)
        #expect(document.projects.first?.clips.first?.trimEnd == 6)
        #expect(document.projects.first?.clips.first?.transitionStyle == .crossfade)
        #expect(document.projects.first?.intertitles == [card])
        #expect(!json.contains("/private/app-container"))
        #expect(!data.isEmpty)
    }

    @Test func includesPreservedRecoveryIssues() async throws {
        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalDataExportRecovery-\(UUID().uuidString)", isDirectory: true)
        let service = LocalDataExportService(outputDirectory: outputDirectory)
        let issue = DraftRecoveryIssue(
            id: UUID(),
            source: "legacy-session",
            message: "Unreadable draft preserved",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let url = try await service.export(
            sessions: [],
            recoveryIssues: [issue],
            exportedAt: Date(timeIntervalSince1970: 1_700_000_100)
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(LocalDataExportDocument.self, from: Data(contentsOf: url))

        #expect(document.recoveryIssues == [issue])
    }
}
