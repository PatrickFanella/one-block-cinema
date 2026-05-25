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

    @Test func attachingClipCompletesMatchingPromptOnly() async throws {
        let firstPrompt = ShotPrompt(index: 0, direction: "Wide", hint: "Set the block", icon: "film")
        let secondPrompt = ShotPrompt(index: 1, direction: "Detail", hint: "Show texture", icon: "eye")
        let clip = FilmClip(
            promptId: secondPrompt.id,
            fileURL: URL(fileURLWithPath: "/tmp/detail.mov"),
            duration: 4
        )

        var session = FilmSession(theme: .documentary, prompts: [firstPrompt, secondPrompt])

        #expect(session.attachClip(clip))
        #expect(session.prompts[0].isCompleted == false)
        #expect(session.prompts[1].isCompleted == true)
        #expect(session.clip(forPromptId: secondPrompt.id) == clip)
    }

    @Test func attachingClipForSamePromptReplacesPreviousClip() async throws {
        let prompt = ShotPrompt(index: 0, direction: "Opening", hint: "Start here", icon: "film")
        let firstClip = FilmClip(
            promptId: prompt.id,
            fileURL: URL(fileURLWithPath: "/tmp/first.mov"),
            duration: 2
        )
        let replacementClip = FilmClip(
            promptId: prompt.id,
            fileURL: URL(fileURLWithPath: "/tmp/replacement.mov"),
            duration: 5
        )

        var session = FilmSession(theme: .documentary, prompts: [prompt])

        #expect(session.attachClip(firstClip))
        #expect(session.attachClip(replacementClip))
        #expect(session.clips.count == 1)
        #expect(session.clip(forPromptId: prompt.id)?.fileURL == replacementClip.fileURL)
        #expect(session.prompts[0].isCompleted)
    }

    @Test func attachingClipForUnknownPromptFailsWithoutMutation() async throws {
        let prompt = ShotPrompt(index: 0, direction: "Opening", hint: "Start here", icon: "film")
        let clip = FilmClip(
            promptId: UUID(),
            fileURL: URL(fileURLWithPath: "/tmp/orphan.mov")
        )

        var session = FilmSession(theme: .documentary, prompts: [prompt])

        #expect(session.attachClip(clip) == false)
        #expect(session.clips.isEmpty)
        #expect(session.prompts[0].isCompleted == false)
    }

    @MainActor
    @Test func viewModelAddsClipToRequestedPromptAndSession() async throws {
        let firstPrompt = ShotPrompt(index: 0, direction: "Wide", hint: "Set the block", icon: "film")
        let secondPrompt = ShotPrompt(index: 1, direction: "Detail", hint: "Show texture", icon: "eye")
        let session = FilmSession(theme: .documentary, prompts: [firstPrompt, secondPrompt])
        let viewModel = FilmSessionViewModel()
        viewModel.activeSession = session
        viewModel.currentPromptIndex = 0

        let clip = try viewModel.addClip(
            from: URL(fileURLWithPath: "/tmp/detail.mov"),
            forPromptId: secondPrompt.id
        )

        #expect(viewModel.activeSession?.id == session.id)
        #expect(viewModel.activeSession?.clips.count == 1)
        #expect(viewModel.activeSession?.clip(forPromptId: secondPrompt.id)?.id == clip.id)
        #expect(viewModel.activeSession?.prompts[0].isCompleted == false)
        #expect(viewModel.activeSession?.prompts[1].isCompleted == true)
        #expect(viewModel.sessions.first?.id == session.id)
    }

}
