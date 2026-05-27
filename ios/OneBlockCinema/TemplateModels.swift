import Foundation

nonisolated enum TemplateAspectRatio: String, CaseIterable, Identifiable, Codable, Sendable, Hashable {
    case vertical = "9:16"
    case square = "1:1"
    case horizontal = "16:9"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .vertical: "Vertical"
        case .square: "Square"
        case .horizontal: "Horizontal"
        }
    }
}

nonisolated struct TemplateDurationTarget: Codable, Sendable, Hashable {
    static let v1MaximumSeconds = 180

    let targetSeconds: Int
    let minimumSeconds: Int
    let maximumSeconds: Int

    init(targetSeconds: Int, minimumSeconds: Int, maximumSeconds: Int) {
        self.targetSeconds = targetSeconds
        self.minimumSeconds = minimumSeconds
        self.maximumSeconds = maximumSeconds
    }

    var fitsV1Maximum: Bool {
        maximumSeconds <= Self.v1MaximumSeconds
    }
}

nonisolated struct TemplateShotPrompt: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let index: Int
    let direction: String
    let hint: String
    let icon: String
    let suggestedDurationSeconds: Int?

    init(
        id: String,
        index: Int,
        direction: String,
        hint: String,
        icon: String,
        suggestedDurationSeconds: Int? = nil
    ) {
        self.id = id
        self.index = index
        self.direction = direction
        self.hint = hint
        self.icon = icon
        self.suggestedDurationSeconds = suggestedDurationSeconds
    }

    func makeSessionPrompt() -> ShotPrompt {
        ShotPrompt(
            index: index,
            direction: direction,
            hint: hint,
            icon: icon
        )
    }
}

nonisolated struct TemplateAssemblyGuidance: Codable, Sendable, Hashable {
    let pacingStyle: PacingStyle
    let editStyle: EditStyle
    let useAmbientSoundtrack: Bool
    let instructions: [String]

    init(
        pacingStyle: PacingStyle,
        editStyle: EditStyle,
        useAmbientSoundtrack: Bool,
        instructions: [String]
    ) {
        self.pacingStyle = pacingStyle
        self.editStyle = editStyle
        self.useAmbientSoundtrack = useAmbientSoundtrack
        self.instructions = instructions
    }
}

nonisolated struct FilmTemplate: Identifiable, Codable, Sendable, Hashable {
    let id: String
    let theme: FilmTheme
    let displayName: String
    let subtitle: String
    let durationTarget: TemplateDurationTarget
    let aspectRatio: TemplateAspectRatio
    let shotCount: Int
    let prompts: [TemplateShotPrompt]
    let assemblyGuidance: TemplateAssemblyGuidance

    init(
        id: String,
        theme: FilmTheme,
        displayName: String,
        subtitle: String,
        durationTarget: TemplateDurationTarget,
        aspectRatio: TemplateAspectRatio,
        shotCount: Int? = nil,
        prompts: [TemplateShotPrompt],
        assemblyGuidance: TemplateAssemblyGuidance
    ) {
        self.id = id
        self.theme = theme
        self.displayName = displayName
        self.subtitle = subtitle
        self.durationTarget = durationTarget
        self.aspectRatio = aspectRatio
        self.shotCount = shotCount ?? prompts.count
        self.prompts = prompts
        self.assemblyGuidance = assemblyGuidance
    }
}

nonisolated enum TemplateCatalog {
    static let launchTemplates: [FilmTemplate] = FilmTheme.allCases.map { template(for: $0) }

    static func template(for theme: FilmTheme) -> FilmTemplate {
        let promptCopy = promptCopy(for: theme)
        let duration = TemplateDurationTarget(targetSeconds: 90, minimumSeconds: 60, maximumSeconds: 180)
        let assembly = TemplateAssemblyGuidance(
            pacingStyle: .rhythmic,
            editStyle: .standard,
            useAmbientSoundtrack: false,
            instructions: assemblyInstructions(for: theme)
        )

        return FilmTemplate(
            id: theme.rawValue,
            theme: theme,
            displayName: theme.displayName,
            subtitle: theme.subtitle,
            durationTarget: duration,
            aspectRatio: .vertical,
            shotCount: promptCopy.count,
            prompts: promptCopy.enumerated().map { index, prompt in
                TemplateShotPrompt(
                    id: "\(theme.rawValue)-shot-\(index + 1)",
                    index: index,
                    direction: prompt.direction,
                    hint: prompt.hint,
                    icon: prompt.icon,
                    suggestedDurationSeconds: 12
                )
            },
            assemblyGuidance: assembly
        )
    }

    private static func promptCopy(for theme: FilmTheme) -> [(direction: String, hint: String, icon: String)] {
        switch theme {
        case .noir:
            return [
                ("Film an establishing shot of the longest shadow you can find", "Look for dramatic light sources casting elongated forms", "building.2.fill"),
                ("Find a repeating pattern and shoot it like evidence", "Grids, lines, tiles — anything that suggests order or obsession", "square.grid.3x3.fill"),
                ("Capture a stranger's hands doing something ordinary", "The way someone holds a cup, checks a phone, fidgets with keys", "hand.raised.fill"),
                ("Record 5 seconds of the most ominous ambient sound", "Traffic drone, wind through an alley, a distant siren", "waveform"),
                ("Shoot one object like it holds a dark secret", "Get close. Make something mundane look like a clue", "magnifyingglass"),
                ("Film a reflection — in glass, water, or metal", "Distorted doubles suggest hidden truths", "drop.fill"),
                ("End with a slow retreat from the scene", "Walk away. Let the camera drift backward into darkness", "arrow.backward"),
            ]
        case .romance:
            return [
                ("Film the softest light you can find", "Golden hour, a lamp through curtains, light on skin", "sun.max.fill"),
                ("Capture two things that belong together", "A pair of shoes, matching colors, parallel paths", "heart.fill"),
                ("Find a gesture of tenderness — real or implied", "A hand on a railing, petals falling, a gentle touch", "hand.point.up.braille.fill"),
                ("Record 5 seconds of a sound that feels warm", "Laughter nearby, birds, rustling leaves, soft music", "waveform"),
                ("Shoot one flower, plant, or living thing with reverence", "Get close enough to notice the details others miss", "leaf.fill"),
                ("Film movement that feels like longing", "Someone walking away, wind carrying something, a closing door", "figure.walk"),
                ("End looking upward — at sky, trees, or open space", "Let the final frame breathe and expand", "arrow.up"),
            ]
        case .documentary:
            return [
                ("Film a wide establishing shot of your entire location", "Show the viewer exactly where they are — set the scene", "mappin.and.ellipse"),
                ("Find the busiest thing happening and observe it", "People, traffic, animals, machinery — don't interfere, just watch", "eye.fill"),
                ("Capture one person's face or posture that tells a story", "Permission with eyes, not words — read the moment", "person.fill"),
                ("Record 10 seconds of pure ambient sound — no movement", "Hold still. Let the place speak for itself", "waveform"),
                ("Shoot the most overlooked detail in this space", "A crack, a stain, a sign, worn paint — what does nobody notice?", "viewfinder"),
                ("Document something in the process of changing", "Construction, decay, growth, a meal being eaten", "arrow.triangle.2.circlepath"),
                ("End with the widest possible shot — pull all the way back", "Context. Show how small this all is in the bigger picture", "arrow.up.left.and.arrow.down.right"),
            ]
        case .horror:
            return [
                ("Film the darkest corner you can find without moving closer", "Zoom if you can. Let the darkness stay distant and unknown", "moon.stars.fill"),
                ("Find something that shouldn't be there — or seems out of place", "A single shoe, an open door, a stain with no source", "exclamationmark.triangle.fill"),
                ("Capture a sudden movement — anything that startles", "A bird taking off, a door swinging, someone turning", "bolt.fill"),
                ("Record 5 seconds of silence — or as close as you can get", "The absence of sound is more unsettling than noise", "waveform"),
                ("Shoot one object from below, looking up at it", "Low angles make ordinary things feel threatening", "arrow.up"),
                ("Film a long empty corridor, hallway, or path", "Hold the shot. Wait. Something might happen", "road.lanes"),
                ("End with a quick snap to black — cover the lens with your hand", "The film doesn't end. It's interrupted", "xmark.circle.fill"),
            ]
        case .dream:
            return [
                ("Film something moving in slow motion — or as slowly as possible", "Water dripping, fabric blowing, clouds drifting", "wind"),
                ("Find a color that doesn't belong and shoot only that", "Isolate it. Make the viewer wonder why it's there", "paintpalette.fill"),
                ("Capture a transition between two textures", "Smooth to rough, wet to dry, natural to artificial", "square.on.square"),
                ("Record 5 seconds of a sound that feels underwater or distant", "Muffled traffic, echoing footsteps, wind through a tunnel", "waveform"),
                ("Shoot through something — glass, mesh, leaves, fingers", "Layer the image. Dreams always have something in the way", "circle.grid.cross.fill"),
                ("Film your own shadow or reflection doing something unexpected", "Become the stranger in your own film", "person.fill.questionmark"),
                ("End by slowly pointing the camera at the sky and holding it", "Let the image dissolve into pure light or pure gray", "sun.max.fill"),
            ]
        }
    }

    private static func assemblyInstructions(for theme: FilmTheme) -> [String] {
        [
            "Arrange clips in template prompt order.",
            "Keep the final short within \(TemplateDurationTarget.v1MaximumSeconds) seconds.",
            "Use the \(theme.displayName.lowercased()) tone as the guide for pacing and titles.",
        ]
    }
}
