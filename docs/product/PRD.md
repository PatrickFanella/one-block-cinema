# One-Block Cinema PRD

## Product idea

A smartphone filmmaking coach for people who want to learn to create well-structured short films.

## Audience

- Beginners with smartphones
- Hobbyist filmmakers
- Students/creators learning film structure
- Future: community participants giving peer feedback

## Core promise

“Turn a smartphone into a step-by-step filmmaking coach for structured 1–3 minute shorts.”

## MVP goal

Help users plan, import clips, assemble, export, share, and get feedback on template-driven 1–3 minute short films.

## MVP must-haves

1. Login with email OTP plus Google/Apple.
2. Ten film templates at launch.
3. Step-by-step guided workflow from idea/template to shot sequence.
4. Import clips from the phone library and attach them to guided prompts.
5. Assemble clips into template-driven shorts up to 180 seconds.
6. Export/share to social platforms.
7. Offline editing/export.
8. Sync projects, drafts, and community activity.
9. Daily and weekly challenges.
10. Comments and peer/community feedback.

## Explicitly not MVP

- AI critique/coach feedback.
- Paid subscriptions or gated templates.
- Desktop/web editing.
- Advanced color grading, audio mixing, or professional NLE features.
- Real in-app camera recording for the MVP milestone.
- Marketplace/community monetization.

## Default creation flow

1. User logs in or resumes a synced/offline draft.
2. User selects a template/challenge.
3. App explains structure and target duration/aspect ratio.
4. App presents shot-by-shot prompts.
5. User imports each clip from the phone library.
6. User reviews assembly, reorders/trims where supported.
7. App previews final short.
8. User exports locally, shares externally, or publishes to community.
9. Community feedback happens after publish; projects are private until publish.

## Template model

- Launch target: 10 templates.
- Templates define stable id, title, outcome, duration target, aspect ratio, shot prompts, and capture/assembly/export guidance.
- Template records are bundled for offline local use; created projects snapshot the prompts and guidance needed to resume without network access.
- Contract: `docs/technical/TEMPLATE_SCHEMA.md`.
- Output length depends on template but must not exceed 180 seconds in v1.
- First production-shaped vertical-slice template: `First Block Story` in the bundled [`FilmTemplates.json`](../../ios/OneBlockCinema/Resources/FilmTemplates.json), a 9:16 beginner micro-documentary with a 60–120 second duration target.

## Community model

- Default visibility: private until publish.
- Profiles: user-editable.
- Launch community features: challenges, comments, peer feedback.
- Challenge cadence: daily and weekly.
- Safety: mixed content with age gating.
- Moderation: manual review, user reports, and automated filters.

## Account/sync model

- Login required for sync and community.
- Auth methods: email OTP, Google, Apple.
- Sync scope: projects, drafts, profile, comments, challenge activity.
- Offline editing/export must work when sync is unavailable.

## Platform

- MVP: iPhone app.
- Web: not required for MVP except possible marketing/admin later.

## Backend/AI

- Backend required for auth, sync, community, challenges, comments, moderation, and age gating.
- AI critique is planned for v2 and should not block v1.

## Monetization

- Free at launch.

## Success metrics

- Creation metric: completed/exported shorts per active user.
- Learning metric: repeat template completion.
- Community metric: challenge participation and useful feedback received.
- Retention metric: weekly returning creators.

## Open product decisions

1. Exact 10 launch templates.
2. First backend/auth provider.
3. Social share/export targets and technical requirements.
4. Age gate policy details and moderation thresholds.

## Closed product decisions

- MVP capture strategy: import-first; real in-app camera recording is post-MVP. See `docs/adr/0002-import-first-capture-mvp.md`.
