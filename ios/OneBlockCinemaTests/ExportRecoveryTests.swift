import Foundation
@testable import OneBlockCinema
import Testing

struct ExportRecoveryTests {
    @Test @MainActor func backgroundExpirationPreservesCheckpointAndRetryCompletes() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let renderService = ControllableRenderService()
        let backgroundTasks = TestBackgroundTaskManager()
        let viewModel = FilmSessionViewModel(
            storage: fixture.storage,
            exportService: renderService,
            backgroundTaskManager: backgroundTasks
        )
        let projectID = try attachExportableClip(to: viewModel, root: fixture.root)

        let firstExport = Task { await viewModel.exportVideo() }
        await waitUntil { viewModel.isExporting && backgroundTasks.hasActiveTask }
        backgroundTasks.expire()
        await firstExport.value

        #expect(viewModel.exportStatusMessage?.contains("background time ended") == true)
        #expect(try await fixture.storage.recoverInterruptedRenders().contains { $0.projectId == projectID })

        let output = fixture.root.appendingPathComponent("retry.mp4")
        try Data("complete".utf8).write(to: output)
        await renderService.succeedImmediately(with: output)
        await viewModel.exportVideo()

        #expect(viewModel.exportedVideoURL == output)
        #expect(try await fixture.storage.recoverInterruptedRenders().isEmpty)
    }

    @Test @MainActor func userCancellationDoesNotCreateRecoveryCheckpoint() async throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let renderService = ControllableRenderService()
        let viewModel = FilmSessionViewModel(storage: fixture.storage, exportService: renderService)
        _ = try attachExportableClip(to: viewModel, root: fixture.root)

        let export = Task { await viewModel.exportVideo() }
        await waitUntil { viewModel.isExporting }
        viewModel.cancelExport()
        await export.value

        #expect(viewModel.exportStatusMessage == "Export cancelled. Your draft is unchanged.")
        #expect(try await fixture.storage.recoverInterruptedRenders().isEmpty)
    }

    @MainActor
    private func attachExportableClip(to viewModel: FilmSessionViewModel, root: URL) throws -> UUID {
        var session = viewModel.createDraft(theme: .documentary)
        let source = root.appendingPathComponent("fixture.mov")
        try Data("video".utf8).write(to: source)
        let prompt = try #require(session.prompts.first)
        let attached = session.attachClip(FilmClip(promptId: prompt.id, fileURL: source, duration: 2))
        #expect(attached)
        viewModel.activeSession = session
        viewModel.saveCurrentSession()
        return session.id
    }

    private func makeFixture() throws -> (storage: SessionStorage, root: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExportRecoveryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let suite = "ExportRecoveryTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        return (SessionStorage(userDefaults: defaults, rootDirectory: root), root)
    }

    @MainActor
    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0 ..< 200 {
            if condition() {
                return
            }
            try? await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("Timed out waiting for export state")
    }
}

private actor ControllableRenderService: RenderService {
    private var continuation: CheckedContinuation<URL, Error>?
    private var immediateOutput: URL?
    private var isCancelled = false

    func makePlan(for project: FilmProject) async throws -> RenderPlan {
        VideoExportLimits.plan(for: project)
    }

    func render(
        plan _: RenderPlan,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        progress(0.25)
        if let immediateOutput {
            return immediateOutput
        }
        if isCancelled {
            isCancelled = false
            throw CancellationError()
        }
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }

    func cancelCurrentRender() {
        if let continuation {
            continuation.resume(throwing: CancellationError())
            self.continuation = nil
        } else {
            isCancelled = true
        }
    }

    func succeedImmediately(with output: URL) {
        isCancelled = false
        immediateOutput = output
    }
}

@MainActor
private final class TestBackgroundTaskManager: BackgroundTaskManaging {
    private var expiration: (@MainActor () -> Void)?
    private(set) var hasActiveTask = false

    func begin(name _: String, expiration: @escaping @MainActor () -> Void) -> BackgroundTaskToken {
        self.expiration = expiration
        hasActiveTask = true
        return BackgroundTaskToken(id: UUID())
    }

    func end(_: BackgroundTaskToken) {
        hasActiveTask = false
        expiration = nil
    }

    func expire() {
        let handler = expiration
        expiration = nil
        handler?()
    }
}
