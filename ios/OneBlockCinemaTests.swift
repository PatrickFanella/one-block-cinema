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

    @Test func decodesSchemaBackedTemplate() throws {
        let sampleJSON = """
        {
          "id": "sample-observation",
          "theme": "documentary",
          "displayName": "One-Block Observation",
          "subtitle": "Truth & observation",
          "durationTarget": {
            "targetSeconds": 90,
            "minimumSeconds": 60,
            "maximumSeconds": 180
          },
          "aspectRatio": "9:16",
          "shotCount": 2,
          "prompts": [
            {
              "id": "sample-observation-shot-1",
              "index": 0,
              "direction": "Film a wide establishing shot of your entire location",
              "hint": "Show the viewer exactly where they are — set the scene",
              "icon": "mappin.and.ellipse",
              "suggestedDurationSeconds": 12
            },
            {
              "id": "sample-observation-shot-2",
              "index": 1,
              "direction": "Find the busiest thing happening and observe it",
              "hint": "Do not interfere; just watch",
              "icon": "eye.fill",
              "suggestedDurationSeconds": 12
            }
          ],
          "assemblyGuidance": {
            "pacingStyle": "rhythmic",
            "editStyle": "standard",
            "useAmbientSoundtrack": false,
            "instructions": [
              "Arrange clips in template prompt order.",
              "Keep the final short within 180 seconds."
            ]
          }
        }
        """

        let template = try JSONDecoder().decode(FilmTemplate.self, from: Data(sampleJSON.utf8))

        #expect(template.id == "sample-observation")
        #expect(template.theme == .documentary)
        #expect(template.aspectRatio == .vertical)
        #expect(template.durationTarget.targetSeconds == 90)
        #expect(template.durationTarget.fitsV1Maximum)
        #expect(template.shotCount == 2)
        #expect(template.prompts[0].direction == "Film a wide establishing shot of your entire location")
        #expect(template.assemblyGuidance.pacingStyle == .rhythmic)
        #expect(template.assemblyGuidance.editStyle == .standard)
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
