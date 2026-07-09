//
//  OneBlockCinemaTests.swift
//  OneBlockCinemaTests
//
//  Created by Rork on March 7, 2026.
//

import Foundation
import Testing
@testable import OneBlockCinema

struct OneBlockCinemaTests {
    private func makeClip(_ number: Int, duration: TimeInterval) -> FilmClip {
        FilmClip(
            id: UUID(),
            promptId: UUID(),
            fileURL: URL(fileURLWithPath: "/tmp/clip\(number).mov"),
            duration: duration
        )
    }

    @MainActor private func makeViewModel() -> (FilmSessionViewModel, SessionStorage) {
        let suiteName = "OneBlockCinemaTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OneBlockCinemaTests-\(UUID().uuidString)", isDirectory: true)
        let storage = SessionStorage(userDefaults: userDefaults, rootDirectory: rootDirectory)
        return (FilmSessionViewModel(storage: storage), storage)
    }

    private func makeStorage() -> (SessionStorage, UserDefaults, URL) {
        let suiteName = "OneBlockCinemaStorageTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        let rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("OneBlockCinemaStorageTests-\(UUID().uuidString)", isDirectory: true)
        return (
            SessionStorage(userDefaults: userDefaults, rootDirectory: rootDirectory),
            userDefaults,
            rootDirectory
        )
    }

    @Test func promptGeneratorCreatesOrderedPromptsForEachTheme() {
        for theme in FilmTheme.allCases {
            let prompts = PromptGenerator.generatePrompts(for: theme)

            #expect(prompts.count == 7)
            #expect(prompts.map(\.index) == Array(0..<7))
            #expect(prompts.allSatisfy { !$0.direction.isEmpty })
            #expect(prompts.allSatisfy { !$0.hint.isEmpty })
            #expect(prompts.allSatisfy { !$0.icon.isEmpty })
            #expect(prompts.allSatisfy { !$0.isCompleted })
        }
    }

    @Test func bundledCatalogContainsTenValidatedTemplates() throws {
        let templates = TemplateCatalog.launchTemplates

        #expect(templates.count == 10)
        #expect(Set(templates.map(\.id)).count == 10)
        #expect(templates.allSatisfy { $0.schemaVersion == 1 })
        #expect(templates.allSatisfy { $0.durationTarget.fitsV1Maximum })
        #expect(templates.allSatisfy { $0.shotPrompts.map(\.index) == Array(0..<$0.shotCount) })
        #expect(templates.flatMap(\.shotPrompts).allSatisfy { !$0.id.isEmpty && $0.targetSeconds > 0 })
    }

    @Test func sessionPromptsPreserveTemplateIdentityAndTiming() throws {
        let template = try #require(TemplateCatalog.template(id: "first-block-story"))
        let prompts = PromptGenerator.generatePrompts(for: template)

        #expect(prompts.map(\.templateShotId) == template.shotPrompts.map(\.id))
        #expect(prompts.map(\.targetSeconds) == template.shotPrompts.map(\.targetSeconds))
    }

    @Test func filmSessionReportsProgressForHappyAndEmptyStates() {
        let completePrompt = ShotPrompt(index: 0, direction: "Wide", hint: "Set the scene", icon: "camera", isCompleted: true)
        let incompletePrompt = ShotPrompt(index: 1, direction: "Detail", hint: "Move closer", icon: "eye")
        let clip = FilmClip(promptId: completePrompt.id, fileURL: URL(fileURLWithPath: "/tmp/clip.mov"), duration: 3)

        let inProgressSession = FilmSession(theme: .documentary, prompts: [completePrompt, incompletePrompt], clips: [clip])
        let emptySession = FilmSession(theme: .dream)
        let completeSession = FilmSession(theme: .documentary, prompts: [completePrompt], clips: [clip])

        #expect(inProgressSession.completedPromptCount == 1)
        #expect(inProgressSession.progress == 0.5)
        #expect(!inProgressSession.isComplete)
        #expect(emptySession.completedPromptCount == 0)
        #expect(emptySession.progress == 0)
        #expect(!emptySession.isComplete)
        #expect(completeSession.isComplete)
    }

    @Test @MainActor func createsNewDraftFromTemplate() async throws {
        let (viewModel, _) = makeViewModel()

        viewModel.startNewSession(theme: .noir)
        await viewModel.waitForPendingPersistence()

        let draft = try #require(viewModel.activeSession)
        #expect(draft.theme == .noir)
        #expect(draft.templateId == "noir-shadow-mystery")
        #expect(draft.templateSchemaVersion == 1)
        #expect(draft.templateTitle == "Noir Shadow Mystery")
        #expect(draft.completedAt == nil)
        #expect(!draft.prompts.isEmpty)
        #expect(viewModel.currentPromptIndex == 0)
        #expect(viewModel.sessions.count == 1)
        #expect(viewModel.sessions.first?.id == draft.id)
    }

    @Test @MainActor func savesAndResumesDraft() async throws {
        let (viewModel, storage) = makeViewModel()
        viewModel.startNewSession(theme: .documentary)
        viewModel.markCurrentPromptCompleted()
        await viewModel.waitForPendingPersistence()

        let savedDraft = try #require(viewModel.sessions.first)
        #expect(savedDraft.completedPromptCount == 1)

        let resumedViewModel = FilmSessionViewModel(storage: storage)
        await resumedViewModel.loadSessions()

        let loadedDraft = try #require(resumedViewModel.sessions.first)
        resumedViewModel.resumeSession(loadedDraft)

        #expect(resumedViewModel.activeSession?.id == savedDraft.id)
        #expect(resumedViewModel.activeSession?.completedPromptCount == 1)
        #expect(resumedViewModel.currentPromptIndex == 1)
    }

    @Test @MainActor func deletesDraftSession() async throws {
        let (viewModel, storage) = makeViewModel()
        viewModel.startNewSession(theme: .horror)
        await viewModel.waitForPendingPersistence()

        let draft = try #require(viewModel.activeSession)
        viewModel.deleteSession(draft)
        await viewModel.waitForPendingPersistence()

        #expect(viewModel.activeSession == nil)
        #expect(viewModel.currentPromptIndex == 0)
        #expect(viewModel.sessions.isEmpty)

        let reloadedViewModel = FilmSessionViewModel(storage: storage)
        await reloadedViewModel.loadSessions()
        #expect(reloadedViewModel.sessions.isEmpty)
    }

    @Test func persistsProjectMetadataAndRelativeMediaPaths() async throws {
        let (storage, _, rootDirectory) = makeStorage()
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("source-\(UUID().uuidString).mov")
        try Data("fixture-video".utf8).write(to: sourceURL)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let prompt = ShotPrompt(index: 0, direction: "Opening", hint: "Start here", icon: "film")
        let sessionId = UUID()
        let durableURL = try await storage.copyClip(sourceURL, for: sessionId)
        let clip = FilmClip(promptId: prompt.id, fileURL: durableURL, duration: 2)
        var session = FilmSession(id: sessionId, theme: .documentary, prompts: [prompt])
        let attached = session.attachClip(clip)
        #expect(attached)

        try await storage.saveSessions([session])
        let loaded = try #require(try await storage.loadSessions().first)
        let loadedClip = try #require(loaded.clips.first)

        #expect(loaded.id == session.id)
        #expect(loadedClip.fileURL == durableURL.standardizedFileURL)
        #expect(loadedClip.mediaStatus == .available)
        #expect(FileManager.default.fileExists(atPath: rootDirectory.appendingPathComponent("projects.sqlite").path))
    }

    @Test func missingMediaIsRecoveredAsAnExplicitState() async throws {
        let (storage, _, _) = makeStorage()
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("source-\(UUID().uuidString).mov")
        try Data("fixture-video".utf8).write(to: sourceURL)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let prompt = ShotPrompt(index: 0, direction: "Opening", hint: "Start here", icon: "film")
        let sessionId = UUID()
        let durableURL = try await storage.copyClip(sourceURL, for: sessionId)
        var session = FilmSession(id: sessionId, theme: .documentary, prompts: [prompt])
        let attached = session.attachClip(FilmClip(promptId: prompt.id, fileURL: durableURL, duration: 2))
        #expect(attached)
        try await storage.saveSessions([session])

        try await storage.deleteClipFile(at: durableURL)
        let loadedClip = try #require(try await storage.loadSessions().first?.clips.first)
        #expect(loadedClip.mediaStatus == .missing)
        #expect(!loadedClip.isMediaAvailable)
    }

    @Test func migratesLegacyUserDefaultsOnlyOnce() async throws {
        let (storage, userDefaults, _) = makeStorage()
        let legacy = FilmSession(theme: .romance, title: "Legacy draft")
        userDefaults.set(try JSONEncoder().encode([legacy]), forKey: "saved_film_sessions")

        let firstLoad = try await storage.loadSessions()
        #expect(firstLoad.map(\.id) == [legacy.id])

        userDefaults.set(try JSONEncoder().encode([FilmSession(theme: .horror)]), forKey: "saved_film_sessions")
        let secondLoad = try await storage.loadSessions()
        #expect(secondLoad.map(\.id) == [legacy.id])
    }

    @Test func recordsUnreadableLegacyMetadataForRecovery() async throws {
        let (storage, userDefaults, _) = makeStorage()
        userDefaults.set(Data("not-json".utf8), forKey: "saved_film_sessions")

        #expect(try await storage.loadSessions().isEmpty)
        let issue = try #require(try await storage.loadRecoveryIssues().first)
        #expect(issue.source == "UserDefaults:saved_film_sessions")
        #expect(issue.message.contains("preserved"))
    }

    @Test func outboxEnqueueIsIdempotentAndRetriesAfterDeadline() async throws {
        let (storage, _, _) = makeStorage()
        let aggregateId = UUID()
        let idempotencyKey = UUID()
        let original = try await storage.enqueueSyncOperation(
            aggregateId: aggregateId,
            kind: .projectUpsert,
            payload: Data("first".utf8),
            idempotencyKey: idempotencyKey
        )
        let duplicate = try await storage.enqueueSyncOperation(
            aggregateId: aggregateId,
            kind: .projectUpsert,
            payload: Data("second".utf8),
            idempotencyKey: idempotencyKey
        )

        #expect(original == duplicate)
        #expect(duplicate.payload == Data("first".utf8))

        let retryAt = Date(timeIntervalSinceNow: 60)
        try await storage.markFailed(id: original.id, error: "offline", retryAt: retryAt)
        #expect(try await storage.loadPendingSyncOperations(now: retryAt.addingTimeInterval(-1)).isEmpty)

        let pending = try await storage.loadPendingSyncOperations(now: retryAt)
        #expect(pending.count == 1)
        #expect(pending.first?.attemptCount == 1)
        #expect(pending.first?.lastError == "offline")

        try await storage.markCompleted(id: original.id)
        #expect(try await storage.loadPendingSyncOperations(now: retryAt).isEmpty)
    }

    @Test func conflictResolutionKeepsServerAndCreatesRecoveredCopy() {
        let projectId = UUID()
        let local = FilmSession(
            id: projectId,
            theme: .documentary,
            revision: 4,
            syncState: .conflict,
            syncEnabled: true,
            title: "My Block"
        )
        let server = FilmSession(
            id: projectId,
            theme: .documentary,
            revision: 5,
            syncState: .synced,
            syncEnabled: true,
            title: "My Block"
        )

        let resolution = SyncConflictResolver.preserveBoth(local: local, server: server)

        #expect(resolution.canonicalProject.id == server.id)
        #expect(resolution.canonicalProject.revision == 5)
        #expect(resolution.recoveredLocalCopy.id != local.id)
        #expect(resolution.recoveredLocalCopy.recoveredFromProjectId == local.id)
        #expect(resolution.recoveredLocalCopy.title.hasSuffix("Recovered Copy"))
        #expect(resolution.recoveredLocalCopy.syncState == .localOnly)
        #expect(!resolution.recoveredLocalCopy.syncEnabled)
    }

    @Test func attachingClipCompletesMatchingPromptOnly() async throws {
        let firstPrompt = ShotPrompt(index: 0, direction: "Wide", hint: "Set the block", icon: "film")
        let secondPrompt = ShotPrompt(index: 1, direction: "Detail", hint: "Show texture", icon: "eye")
        let clip = FilmClip(promptId: secondPrompt.id, fileURL: URL(fileURLWithPath: "/tmp/detail.mov"), duration: 4)

        var session = FilmSession(theme: .documentary, prompts: [firstPrompt, secondPrompt])
        let attached = session.attachClip(clip)

        #expect(attached)
        #expect(session.prompts[0].isCompleted == false)
        #expect(session.prompts[1].isCompleted == true)
        #expect(session.clip(forPromptId: secondPrompt.id) == clip)
    }

    @Test func attachingClipForSamePromptReplacesPreviousClip() async throws {
        let prompt = ShotPrompt(index: 0, direction: "Opening", hint: "Start here", icon: "film")
        let firstClip = FilmClip(promptId: prompt.id, fileURL: URL(fileURLWithPath: "/tmp/first.mov"), duration: 2)
        let replacementClip = FilmClip(promptId: prompt.id, fileURL: URL(fileURLWithPath: "/tmp/replacement.mov"), duration: 5)

        var session = FilmSession(theme: .documentary, prompts: [prompt])
        let attachedFirstClip = session.attachClip(firstClip)
        let attachedReplacementClip = session.attachClip(replacementClip)

        #expect(attachedFirstClip)
        #expect(attachedReplacementClip)
        #expect(session.clips.count == 1)
        #expect(session.clip(forPromptId: prompt.id)?.fileURL == replacementClip.fileURL)
        #expect(session.prompts[0].isCompleted)
    }

    @Test func attachingClipForUnknownPromptFailsWithoutMutation() async throws {
        let prompt = ShotPrompt(index: 0, direction: "Opening", hint: "Start here", icon: "film")
        let clip = FilmClip(promptId: UUID(), fileURL: URL(fileURLWithPath: "/tmp/orphan.mov"))

        var session = FilmSession(theme: .documentary, prompts: [prompt])

        #expect(session.attachClip(clip) == false)
        #expect(session.clips.isEmpty)
        #expect(session.prompts[0].isCompleted == false)
    }

    @Test func catalogTemplateCreatesSessionPrompts() throws {
        let template = TemplateCatalog.template(for: .noir)
        let prompts = PromptGenerator.generatePrompts(for: template)

        #expect(template.durationTarget.fitsV1Maximum)
        #expect(template.aspectRatio == .vertical)
        #expect(template.shotCount == prompts.count)
        #expect(prompts.first?.direction == template.prompts.first?.direction)
        #expect(prompts.first?.isCompleted == false)
    }

    @Test func planKeepsClipsUnderMaxDuration() async throws {
        let clips = [makeClip(1, duration: 30), makeClip(2, duration: 45), makeClip(3, duration: 15)]

        let plan = VideoExportLimits.plan(for: clips, maxDuration: 120)

        #expect(plan.segments.count == 3)
        #expect(plan.segments.map(\.duration) == [30, 45, 15])
        #expect(plan.totalDuration == 90)
        #expect(plan.wasTrimmedToMaximumDuration == false)
    }

    @Test func planTrimsClipThatCrossesMaxDuration() async throws {
        let clips = [makeClip(1, duration: 90), makeClip(2, duration: 50)]

        let plan = VideoExportLimits.plan(for: clips, maxDuration: 100)

        #expect(plan.segments.count == 2)
        #expect(plan.segments[0].duration == 90)
        #expect(plan.segments[1].duration == 10)
        #expect(plan.totalDuration == 100)
        #expect(plan.wasTrimmedToMaximumDuration == true)
    }

    @Test func clipsInPromptOrderUsesShotPromptOrder() async throws {
        let firstPrompt = ShotPrompt(index: 0, direction: "First", hint: "", icon: "1.circle")
        let secondPrompt = ShotPrompt(index: 1, direction: "Second", hint: "", icon: "2.circle")
        let thirdPrompt = ShotPrompt(index: 2, direction: "Third", hint: "", icon: "3.circle")

        let thirdClip = FilmClip(promptId: thirdPrompt.id, fileURL: URL(fileURLWithPath: "/tmp/third.mov"))
        let firstClip = FilmClip(promptId: firstPrompt.id, fileURL: URL(fileURLWithPath: "/tmp/first.mov"))
        let secondClip = FilmClip(promptId: secondPrompt.id, fileURL: URL(fileURLWithPath: "/tmp/second.mov"))

        let session = FilmSession(theme: .documentary, prompts: [firstPrompt, secondPrompt, thirdPrompt], clips: [thirdClip, firstClip, secondClip])

        #expect(session.clipsInPromptOrder.map(\.id) == [firstClip.id, secondClip.id, thirdClip.id])
    }
}
