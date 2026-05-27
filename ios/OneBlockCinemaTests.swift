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

    @Test func planKeepsClipsUnderMaxDuration() async throws {
        let clips = [
            makeClip(1, duration: 30),
            makeClip(2, duration: 45),
            makeClip(3, duration: 15)
        ]

        let plan = VideoExportLimits.plan(for: clips, maxDuration: 120)

        #expect(plan.segments.count == 3)
        #expect(plan.segments.map(\.duration) == [30, 45, 15])
        #expect(plan.totalDuration == 90)
        #expect(plan.wasTrimmedToMaximumDuration == false)
    }

    @Test func planTrimsClipThatCrossesMaxDuration() async throws {
        let clips = [
            makeClip(1, duration: 90),
            makeClip(2, duration: 50)
        ]

        let plan = VideoExportLimits.plan(for: clips, maxDuration: 100)

        #expect(plan.segments.count == 2)
        #expect(plan.segments[0].duration == 90)
        #expect(plan.segments[1].duration == 10)
        #expect(plan.totalDuration == 100)
        #expect(plan.wasTrimmedToMaximumDuration == true)
    }

    @Test func planIgnoresZeroDurationClipsAndNoExportableClips() async throws {
        let clips = [
            makeClip(1, duration: 0),
            makeClip(2, duration: 0)
        ]

        let plan = VideoExportLimits.plan(for: clips, maxDuration: 120)

        #expect(plan.segments.isEmpty)
        #expect(plan.totalDuration == 0)
        #expect(plan.wasTrimmedToMaximumDuration == false)

        let noExportablePlan = VideoExportLimits.plan(for: [], maxDuration: 120)

        #expect(noExportablePlan.segments.isEmpty)
        #expect(noExportablePlan.totalDuration == 0)
        #expect(noExportablePlan.wasTrimmedToMaximumDuration == false)
    }

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
