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

    @Test func clipsInPromptOrderUsesShotPromptOrder() async throws {
        let firstPrompt = ShotPrompt(index: 0, direction: "First", hint: "", icon: "1.circle")
        let secondPrompt = ShotPrompt(index: 1, direction: "Second", hint: "", icon: "2.circle")
        let thirdPrompt = ShotPrompt(index: 2, direction: "Third", hint: "", icon: "3.circle")

        let thirdClip = FilmClip(promptId: thirdPrompt.id, fileURL: URL(fileURLWithPath: "/tmp/third.mov"))
        let firstClip = FilmClip(promptId: firstPrompt.id, fileURL: URL(fileURLWithPath: "/tmp/first.mov"))
        let secondClip = FilmClip(promptId: secondPrompt.id, fileURL: URL(fileURLWithPath: "/tmp/second.mov"))

        let session = FilmSession(
            theme: .documentary,
            prompts: [firstPrompt, secondPrompt, thirdPrompt],
            clips: [thirdClip, firstClip, secondClip]
        )

        #expect(session.clipsInPromptOrder.map(\.id) == [firstClip.id, secondClip.id, thirdClip.id])
    }

    @Test func clipsInPromptOrderPlacesUnmatchedClipsAfterPromptedClips() async throws {
        let prompt = ShotPrompt(index: 0, direction: "Prompted", hint: "", icon: "1.circle")
        let promptedClip = FilmClip(promptId: prompt.id, fileURL: URL(fileURLWithPath: "/tmp/prompted.mov"))
        let unmatchedClip = FilmClip(promptId: UUID(), fileURL: URL(fileURLWithPath: "/tmp/unmatched.mov"))

        let session = FilmSession(
            theme: .documentary,
            prompts: [prompt],
            clips: [unmatchedClip, promptedClip]
        )

        #expect(session.clipsInPromptOrder.map(\.id) == [promptedClip.id, unmatchedClip.id])
    }

}
