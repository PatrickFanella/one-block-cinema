# Launch Templates

The production template catalog is bundled directly with the iOS application:

- [`FilmTemplates.json`](../../../ios/OneBlockCinema/Resources/FilmTemplates.json) — all 10 launch templates.
- [`FilmTemplateV1.schema.json`](../../../ios/OneBlockCinema/Resources/FilmTemplateV1.schema.json) — the versioned JSON Schema contract.

Keeping the only catalog copy in the app prevents documentation data from drifting away from executable behavior. `python3 scripts/validate_templates.py` validates catalog count, stable ids, prompt ordering, duration bounds, guidance, and assembly defaults.
