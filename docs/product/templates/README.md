# Launch Templates

Production-shaped film templates live here as data before they are expanded into the in-app template catalog.

## Required template fields

Each template must include:

- `schemaVersion`
- `id`
- `title`
- `outcome`
- `durationTargetSeconds.min`, `durationTargetSeconds.ideal`, and `durationTargetSeconds.max`
- `aspectRatio`
- `shotPrompts[]` with `id`, `title`, `structureRole`, `direction`, `hint`, and `targetSeconds`
- `guidance.structure`, `guidance.capture`, `guidance.assembly`, and `guidance.export`

Duration targets must stay within the MVP 1–3 minute cap.

## Current vertical-slice template

- [`first-block-story.json`](first-block-story.json) — a beginner-friendly one-block micro-documentary that teaches beginning/middle/end structure through seven smartphone shots.
