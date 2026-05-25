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
    private let storageKey = "saved_film_sessions"

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

    @Test func filmSessionReportsProgressForHappyAndEmptyStates() {
        let completePrompt = ShotPrompt(index: 0, direction: "Wide", hint: "Set the scene", icon: "camera", isCompleted: true)
        let incompletePrompt = ShotPrompt(index: 1, direction: "Detail", hint: "Move closer", icon: "eye")
        let clip = FilmClip(promptId: completePrompt.id, fileURL: URL(fileURLWithPath: "/tmp/clip.mov"), duration: 3)

        let inProgressSession = FilmSession(theme: .documentary, prompts: [completePrompt, incompletePrompt], clips: [clip])
        let emptySession = FilmSession(theme: .dream)
        let completeSession = FilmSession(
            theme: .documentary,
            prompts: [completePrompt],
            clips: [clip]
        )

        #expect(inProgressSession.completedPromptCount == 1)
        #expect(inProgressSession.progress == 0.5)
        #expect(!inProgressSession.isComplete)
        #expect(emptySession.completedPromptCount == 0)
        #expect(emptySession.progress == 0)
        #expect(!emptySession.isComplete)
        #expect(completeSession.isComplete)
    }

    @MainActor
    @Test func startNewSessionBuildsPromptBackedDraft() {
        let viewModel = FilmSessionViewModel()

        viewModel.startNewSession(theme: .noir)

        #expect(viewModel.activeSession?.theme == .noir)
        #expect(viewModel.activeSession?.prompts.count == 7)
        #expect(viewModel.activeSession?.clips.isEmpty == true)
        #expect(viewModel.activeSession?.completedPromptCount == 0)
        #expect(viewModel.currentPromptIndex == 0)
        #expect(viewModel.currentPrompt?.index == 0)
        #expect(viewModel.hasNextPrompt)
        #expect(!viewModel.hasPreviousPrompt)
    }

    @Test func sessionStorageRoundTripsSavedSessionsAndIgnoresInvalidData() async throws {
        UserDefaults.standard.removeObject(forKey: storageKey)
        defer { UserDefaults.standard.removeObject(forKey: storageKey) }

        let storage = SessionStorage()
        let prompt = ShotPrompt(index: 0, direction: "Find a subject", hint: "Keep it simple", icon: "camera", isCompleted: true)
        let clip = FilmClip(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            promptId: prompt.id,
            fileURL: URL(fileURLWithPath: "/tmp/clip.mov"),
            thumbnailURL: URL(fileURLWithPath: "/tmp/thumb.jpg"),
            duration: 4.5,
            createdAt: Date(timeIntervalSince1970: 123),
            showTitle: false,
            titleText: "Opening detail"
        )
        let session = FilmSession(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            theme: .horror,
            prompts: [prompt],
            clips: [clip],
            pacingStyle: .slowCinema,
            editStyle: .voiceoverDiary,
            useAmbientSoundtrack: true,
            createdAt: Date(timeIntervalSince1970: 456),
            completedAt: Date(timeIntervalSince1970: 789),
            title: "Alley test"
        )

        await storage.saveSessions([session])

        let loadedSessions = await storage.loadSessions()
        #expect(loadedSessions.count == 1)
        let loadedSession = try #require(loadedSessions.first)
        #expect(loadedSession.id == session.id)
        #expect(loadedSession.theme == .horror)
        #expect(loadedSession.prompts.first?.direction == "Find a subject")
        #expect(loadedSession.prompts.first?.isCompleted == true)
        #expect(loadedSession.clips.first?.fileURL.path == "/tmp/clip.mov")
        #expect(loadedSession.clips.first?.titleText == "Opening detail")
        #expect(loadedSession.pacingStyle == .slowCinema)
        #expect(loadedSession.editStyle == .voiceoverDiary)
        #expect(loadedSession.useAmbientSoundtrack == true)
        #expect(loadedSession.title == "Alley test")

        UserDefaults.standard.set(Data("not-json".utf8), forKey: storageKey)
        let invalidSessions = await storage.loadSessions()
        #expect(invalidSessions.isEmpty)
    }

}
