import Foundation

struct PromptGenerator {
    static func generatePrompts(for template: FilmTemplate) -> [ShotPrompt] {
        template.prompts
    }

    static func generatePrompts(for theme: FilmTheme) -> [ShotPrompt] {
        let prompts: [(String, String, String)]

        switch theme {
        case .noir:
            prompts = [
                ("Film an establishing shot of the longest shadow you can find", "Look for dramatic light sources casting elongated forms", "building.2.fill"),
                ("Find a repeating pattern and shoot it like evidence", "Grids, lines, tiles — anything that suggests order or obsession", "square.grid.3x3.fill"),
                ("Capture a stranger's hands doing something ordinary", "The way someone holds a cup, checks a phone, fidgets with keys", "hand.raised.fill"),
                ("Record 5 seconds of the most ominous ambient sound", "Traffic drone, wind through an alley, a distant siren", "waveform"),
                ("Shoot one object like it holds a dark secret", "Get close. Make something mundane look like a clue", "magnifyingglass"),
                ("Film a reflection — in glass, water, or metal", "Distorted doubles suggest hidden truths", "drop.fill"),
                ("End with a slow retreat from the scene", "Walk away. Let the camera drift backward into darkness", "arrow.backward"),
            ]

        case .romance:
            prompts = [
                ("Film the softest light you can find", "Golden hour, a lamp through curtains, light on skin", "sun.max.fill"),
                ("Capture two things that belong together", "A pair of shoes, matching colors, parallel paths", "heart.fill"),
                ("Find a gesture of tenderness — real or implied", "A hand on a railing, petals falling, a gentle touch", "hand.point.up.braille.fill"),
                ("Record 5 seconds of a sound that feels warm", "Laughter nearby, birds, rustling leaves, soft music", "waveform"),
                ("Shoot one flower, plant, or living thing with reverence", "Get close enough to notice the details others miss", "leaf.fill"),
                ("Film movement that feels like longing", "Someone walking away, wind carrying something, a closing door", "figure.walk"),
                ("End looking upward — at sky, trees, or open space", "Let the final frame breathe and expand", "arrow.up"),
            ]

        case .documentary:
            prompts = [
                ("Film a wide establishing shot of your entire location", "Show the viewer exactly where they are — set the scene", "mappin.and.ellipse"),
                ("Find the busiest thing happening and observe it", "People, traffic, animals, machinery — don't interfere, just watch", "eye.fill"),
                ("Capture one person's face or posture that tells a story", "Permission with eyes, not words — read the moment", "person.fill"),
                ("Record 10 seconds of pure ambient sound — no movement", "Hold still. Let the place speak for itself", "waveform"),
                ("Shoot the most overlooked detail in this space", "A crack, a stain, a sign, worn paint — what does nobody notice?", "viewfinder"),
                ("Document something in the process of changing", "Construction, decay, growth, a meal being eaten", "arrow.triangle.2.circlepath"),
                ("End with the widest possible shot — pull all the way back", "Context. Show how small this all is in the bigger picture", "arrow.up.left.and.arrow.down.right"),
            ]

        case .horror:
            prompts = [
                ("Film the darkest corner you can find without moving closer", "Zoom if you can. Let the darkness stay distant and unknown", "moon.stars.fill"),
                ("Find something that shouldn't be there — or seems out of place", "A single shoe, an open door, a stain with no source", "exclamationmark.triangle.fill"),
                ("Capture a sudden movement — anything that startles", "A bird taking off, a door swinging, someone turning", "bolt.fill"),
                ("Record 5 seconds of silence — or as close as you can get", "The absence of sound is more unsettling than noise", "waveform"),
                ("Shoot one object from below, looking up at it", "Low angles make ordinary things feel threatening", "arrow.up"),
                ("Film a long empty corridor, hallway, or path", "Hold the shot. Wait. Something might happen", "road.lanes"),
                ("End with a quick snap to black — cover the lens with your hand", "The film doesn't end. It's interrupted", "xmark.circle.fill"),
            ]

        case .dream:
            prompts = [
                ("Film something moving in slow motion — or as slowly as possible", "Water dripping, fabric blowing, clouds drifting", "wind"),
                ("Find a color that doesn't belong and shoot only that", "Isolate it. Make the viewer wonder why it's there", "paintpalette.fill"),
                ("Capture a transition between two textures", "Smooth to rough, wet to dry, natural to artificial", "square.on.square"),
                ("Record 5 seconds of a sound that feels underwater or distant", "Muffled traffic, echoing footsteps, wind through a tunnel", "waveform"),
                ("Shoot through something — glass, mesh, leaves, fingers", "Layer the image. Dreams always have something in the way", "circle.grid.cross.fill"),
                ("Film your own shadow or reflection doing something unexpected", "Become the stranger in your own film", "person.fill.questionmark"),
                ("End by slowly pointing the camera at the sky and holding it", "Let the image dissolve into pure light or pure gray", "sun.max.fill"),
            ]
        }

        return prompts.enumerated().map { index, prompt in
            ShotPrompt(
                index: index,
                direction: prompt.0,
                hint: prompt.1,
                icon: prompt.2
            )
        }
    }
}
