# Film Template Schema

This contract defines launch-ready film templates for local, offline-first use in
the iPhone app. Templates are bundled with the app as static data for MVP; sync
may later deliver versioned template updates, but project creation must not
depend on a network request.

The executable sources of truth are:

- `ios/OneBlockCinema/Resources/FilmTemplateV1.schema.json`
- `ios/OneBlockCinema/Resources/FilmTemplates.json`

## Contract

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `id` | string | Yes | Stable kebab-case identifier, unique across bundled and synced templates. |
| `schemaVersion` | integer | Yes | Starts at `1`; increment only for breaking contract changes. |
| `title` | string | Yes | User-facing template name. |
| `subtitle` | string | Yes | Short picker description. |
| `outcome` | string | Yes | Plain-language promise of the completed short. |
| `theme` | enum | Yes | Visual family: `noir`, `romance`, `documentary`, `horror`, or `dream`. |
| `difficulty` | enum | Yes | `beginner` or `intermediate`. |
| `aspectRatio` | enum | Yes | One of `9:16`, `1:1`, `16:9`, `4:5`. |
| `durationTargetSeconds` | object | Yes | `{ "min": number, "ideal": number, "max": number }`; max must be `<= 180`. |
| `tags` | array | Yes | Local discovery and editorial tags. |
| `shotPrompts` | array | Yes | Ordered prompts; each item has an offline-stable id, direction, hint, icon, and target seconds. |
| `guidance` | object | Yes | Beginner coaching for structure, capture, assembly, and export. |
| `assembly` | object | Yes | Default pacing, edit style, and ambient soundtrack preference. |

### `durationTargetSeconds`

- `min`: shortest recommended final runtime.
- `ideal`: target runtime shown in planning/export UI.
- `max`: hard template maximum; v1 export must never exceed 180 seconds.

### `shotPrompts[]`

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `id` | string | Yes | Stable within the template, e.g. `opening-shadow`. |
| `index` | integer | Yes | Zero-based ordering for capture and assembly. |
| `title` | string | Yes | Short step title. |
| `structureRole` | string | Yes | Narrative job performed by the shot. |
| `direction` | string | Yes | Primary instruction shown to the creator. |
| `hint` | string | Yes | Beginner-friendly coaching detail. |
| `icon` | string | Yes | Bundled SF Symbol name; no remote image dependency. |
| `targetSeconds` | integer | Yes | Planned clip length for pacing and assembly. |

### `guidance`

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `structure` | string | Yes | Explains beginning/middle/end shape. |
| `capture` | string | Yes | On-set shooting/import coaching. |
| `assembly` | string | Yes | Edit-order and pacing guidance. |
| `export` | string | Yes | Aspect ratio, duration, and sharing guidance. |

### `assembly`

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `pacingStyle` | enum | Yes | `quick_cuts`, `slow_cinema`, or `rhythmic`. |
| `editStyle` | enum | Yes | `standard`, `silent_film`, or `voiceover_diary`. |
| `useAmbientSoundtrack` | boolean | Yes | Default audio-bed preference. |

## Offline compatibility rules

- Template records must be self-contained: no remote images, media URLs, feature
  flags, server ids, or network-only dependencies.
- Template ids and shot prompt ids must be stable so locally saved drafts can
  resume after app relaunch or later template updates.
- A created project should snapshot the template id, shot prompts, duration
  target, aspect ratio, and guidance needed to continue offline.
- Later synced templates must be additive or versioned; they must not invalidate
  existing local drafts.

## Production catalog

See `ios/OneBlockCinema/Resources/FilmTemplates.json` for complete examples that are decoded and displayed by the application.
