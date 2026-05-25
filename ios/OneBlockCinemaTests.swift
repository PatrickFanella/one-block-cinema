//
//  OneBlockCinemaTests.swift
//  OneBlockCinemaTests
//
//  Created by Rork on March 7, 2026.
//

import Testing
import Foundation
@testable import OneBlockCinema

struct OneBlockCinemaTests {

    @Test @MainActor func createsNewDraftFromTemplate() async throws {
        let (viewModel, _) = makeViewModel()

        viewModel.startNewSession(theme: .noir)
        await viewModel.waitForPendingPersistence()

        let draft = try #require(viewModel.activeSession)
        #expect(draft.theme == .noir)
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

    @MainActor private func makeViewModel() -> (FilmSessionViewModel, SessionStorage) {
        let suiteName = "OneBlockCinemaTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        let storage = SessionStorage(userDefaults: userDefaults)
        return (FilmSessionViewModel(storage: storage), storage)
    }

}
