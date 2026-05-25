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

}
