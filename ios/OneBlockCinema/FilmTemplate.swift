import Foundation

nonisolated enum TemplateAspectRatio: String, CaseIterable, Codable, Sendable, Hashable {
    case vertical9x16 = "9:16"
    case square1x1 = "1:1"
    case horizontal16x9 = "16:9"
    case portrait4x5 = "4:5"
}

nonisolated struct TemplateDurationTarget: Codable, Sendable, Hashable {
    let min: Int
    let ideal: Int
    let max: Int
}

nonisolated struct TemplateShotPrompt: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let index: Int
    let direction: String
    let hint: String
    let icon: String
    let targetSeconds: Int

    func makeShotPrompt() -> ShotPrompt {
        ShotPrompt(
            templateShotId: id,
            index: index,
            direction: direction,
            hint: hint,
            icon: icon,
            targetSeconds: targetSeconds
        )
    }
}

nonisolated struct TemplateGuidance: Codable, Sendable, Hashable {
    let structure: String
    let capture: String
    let assembly: String
    let export: String
}

nonisolated struct FilmTemplate: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let schemaVersion: Int
    let title: String
    let outcome: String
    let aspectRatio: TemplateAspectRatio
    let durationTargetSeconds: TemplateDurationTarget
    let shotPrompts: [TemplateShotPrompt]
    let guidance: TemplateGuidance

    var prompts: [ShotPrompt] {
        shotPrompts
            .sorted { $0.index < $1.index }
            .map { $0.makeShotPrompt() }
    }
}

extension FilmTemplate {
    static let launchTemplates = [noirShadowMystery]

    static func template(for theme: FilmTheme) -> FilmTemplate? {
        switch theme {
        case .noir: noirShadowMystery
        case .romance, .documentary, .horror, .dream: nil
        }
    }

    static let noirShadowMystery = FilmTemplate(
        id: "noir-shadow-mystery",
        schemaVersion: 1,
        title: "Noir Shadow Mystery",
        outcome: "A tense 60-second mystery built from shadows, clues, and one unresolved ending.",
        aspectRatio: .vertical9x16,
        durationTargetSeconds: TemplateDurationTarget(min: 45, ideal: 60, max: 75),
        shotPrompts: [
            TemplateShotPrompt(
                id: "long-shadow",
                index: 0,
                direction: "Film an establishing shot of the longest shadow you can find.",
                hint: "Look for dramatic light sources casting elongated forms.",
                icon: "building.2.fill",
                targetSeconds: 8
            ),
            TemplateShotPrompt(
                id: "pattern-evidence",
                index: 1,
                direction: "Find a repeating pattern and shoot it like evidence.",
                hint: "Grids, lines, tiles — anything that suggests order or obsession.",
                icon: "square.grid.3x3.fill",
                targetSeconds: 8
            ),
            TemplateShotPrompt(
                id: "ordinary-hands",
                index: 2,
                direction: "Capture hands doing something ordinary.",
                hint: "The way someone holds a cup, checks a phone, or fidgets with keys can imply a story.",
                icon: "hand.raised.fill",
                targetSeconds: 7
            ),
            TemplateShotPrompt(
                id: "ominous-sound",
                index: 3,
                direction: "Record 5 seconds of the most ominous ambient sound nearby.",
                hint: "Traffic drone, wind through an alley, a distant siren, or an empty room tone all work.",
                icon: "waveform",
                targetSeconds: 5
            ),
            TemplateShotPrompt(
                id: "secret-object",
                index: 4,
                direction: "Shoot one object like it holds a dark secret.",
                hint: "Get close. Make something mundane look like a clue.",
                icon: "magnifyingglass",
                targetSeconds: 7
            ),
            TemplateShotPrompt(
                id: "distorted-reflection",
                index: 5,
                direction: "Film a reflection in glass, water, or metal.",
                hint: "Distorted doubles suggest hidden truths.",
                icon: "drop.fill",
                targetSeconds: 8
            ),
            TemplateShotPrompt(
                id: "retreat-ending",
                index: 6,
                direction: "End with a slow retreat from the scene.",
                hint: "Walk away. Let the camera drift backward into darkness.",
                icon: "arrow.backward",
                targetSeconds: 10
            ),
        ],
        guidance: TemplateGuidance(
            structure: "Open with place, build suspicion through details, then leave one unanswered question.",
            capture: "Hold each shot steady, use available contrast, and avoid explaining the mystery with dialogue.",
            assembly: "Cut from wide to detail to reflection, using the ambient sound as the mood bed.",
            export: "Export vertical 9:16 at about one minute; trim before export if the assembly exceeds 75 seconds."
        )
    )
}
