# Film Template Schema

This contract defines launch-ready film templates for local, offline-first use in
the iPhone app. Templates are bundled with the app as static data for MVP; sync
may later deliver versioned template updates, but project creation must not
depend on a network request.

## Contract

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `id` | string | Yes | Stable kebab-case identifier, unique across bundled and synced templates. |
| `schemaVersion` | integer | Yes | Starts at `1`; increment only for breaking contract changes. |
| `title` | string | Yes | User-facing template name. |
| `outcome` | string | Yes | Plain-language promise of the completed short. |
| `aspectRatio` | enum | Yes | One of `9:16`, `1:1`, `16:9`, `4:5`. |
| `durationTargetSeconds` | object | Yes | `{ "min": number, "ideal": number, "max": number }`; max must be `<= 180`. |
| `shotPrompts` | array | Yes | Ordered prompts; each item has an offline-stable id, direction, hint, icon, and target seconds. |
| `guidance` | object | Yes | Beginner coaching for structure, capture, assembly, and export. |

### `durationTargetSeconds`

- `min`: shortest recommended final runtime.
- `ideal`: target runtime shown in planning/export UI.
- `max`: hard template maximum; v1 export must never exceed 180 seconds.

### `shotPrompts[]`

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| `id` | string | Yes | Stable within the template, e.g. `opening-shadow`. |
| `index` | integer | Yes | Zero-based ordering for capture and assembly. |
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

## Offline compatibility rules

- Template records must be self-contained: no remote images, media URLs, feature
  flags, server ids, or network-only dependencies.
- Template ids and shot prompt ids must be stable so locally saved drafts can
  resume after app relaunch or later template updates.
- A created project should snapshot the template id, shot prompts, duration
  target, aspect ratio, and guidance needed to continue offline.
- Later synced templates must be additive or versioned; they must not invalidate
  existing local drafts.

## Example template

```json
{
  "id": "noir-shadow-mystery",
  "schemaVersion": 1,
  "title": "Noir Shadow Mystery",
  "outcome": "A tense 60-second mystery built from shadows, clues, and one unresolved ending.",
  "aspectRatio": "9:16",
  "durationTargetSeconds": {
    "min": 45,
    "ideal": 60,
    "max": 75
  },
  "shotPrompts": [
    {
      "id": "long-shadow",
      "index": 0,
      "direction": "Film an establishing shot of the longest shadow you can find.",
      "hint": "Look for dramatic light sources casting elongated forms.",
      "icon": "building.2.fill",
      "targetSeconds": 8
    },
    {
      "id": "pattern-evidence",
      "index": 1,
      "direction": "Find a repeating pattern and shoot it like evidence.",
      "hint": "Grids, lines, tiles — anything that suggests order or obsession.",
      "icon": "square.grid.3x3.fill",
      "targetSeconds": 8
    },
    {
      "id": "ordinary-hands",
      "index": 2,
      "direction": "Capture hands doing something ordinary.",
      "hint": "The way someone holds a cup, checks a phone, or fidgets with keys can imply a story.",
      "icon": "hand.raised.fill",
      "targetSeconds": 7
    },
    {
      "id": "ominous-sound",
      "index": 3,
      "direction": "Record 5 seconds of the most ominous ambient sound nearby.",
      "hint": "Traffic drone, wind through an alley, a distant siren, or an empty room tone all work.",
      "icon": "waveform",
      "targetSeconds": 5
    },
    {
      "id": "secret-object",
      "index": 4,
      "direction": "Shoot one object like it holds a dark secret.",
      "hint": "Get close. Make something mundane look like a clue.",
      "icon": "magnifyingglass",
      "targetSeconds": 7
    },
    {
      "id": "distorted-reflection",
      "index": 5,
      "direction": "Film a reflection in glass, water, or metal.",
      "hint": "Distorted doubles suggest hidden truths.",
      "icon": "drop.fill",
      "targetSeconds": 8
    },
    {
      "id": "retreat-ending",
      "index": 6,
      "direction": "End with a slow retreat from the scene.",
      "hint": "Walk away. Let the camera drift backward into darkness.",
      "icon": "arrow.backward",
      "targetSeconds": 10
    }
  ],
  "guidance": {
    "structure": "Open with place, build suspicion through details, then leave one unanswered question.",
    "capture": "Hold each shot steady, use available contrast, and avoid explaining the mystery with dialogue.",
    "assembly": "Cut from wide to detail to reflection, using the ambient sound as the mood bed.",
    "export": "Export vertical 9:16 at about one minute; trim before export if the assembly exceeds 75 seconds."
  }
}
```
