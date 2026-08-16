# MVP Scope

## MVP definition

An iPhone app where a beginner or hobbyist can choose a film template, follow guided shot prompts, import clips, assemble a 1–3 minute short, export/share it, and optionally publish for community feedback.

## Current executable slice

- 10 launch templates exist.
- Guided prompt flow exists.
- Native 1080p camera recording and Photos-library import both attach clips to guided prompts; physical-device QA remains incomplete.
- Local-first draft metadata and imported media persistence exist.
- User-controlled clip order and non-destructive in/out trim points persist locally and affect preview/export.
- Cuts/pacing-aware crossfades, clip title overlays, source-audio levels, and standard/silent-film looks use the same preview/export render path.
- Preview is real AVPlayer playback driven by the same normalized render plan as export.
- Export/share produces a cancellable, template-aspect MP4 with progress, disk checks, audio preservation, and a 180-second cap; media-fixture/device QA remains incomplete.
- Auth/sync/community are not connected to the iOS app. Credential-free API, worker, RLS, and moderation-console foundations exist with community flags off.
- Linux verification checks backend/schema contracts but does not build or test the iOS app; use macOS/Xcode for app behavior checks.

## In scope

### Onboarding/account

- Login with email OTP, Google, and Apple.
- User-editable profile.
- Private-until-publish default.

### Templates/guidance

- 10 launch templates.
- Template-defined aspect ratio and duration target.
- Step-by-step prompt sequence.
- Beginner-friendly film structure coaching.
- Offline-compatible template contract documented in `docs/technical/TEMPLATE_SCHEMA.md`.

### Capture/import

- Users can record with the guided AVFoundation camera or import from the iOS photo library.
- Tag clips to template prompts.
- Save drafts locally for offline work.

### Assembly/export

- Start from template order and rearrange clips explicitly.
- Set non-destructive in/out trim points.
- Preview final short.
- Export/share final video.
- Hard cap: 180 seconds.
- Offline editing/export required.

### Sync/community

- Sync projects, drafts, profile, comments, and challenge activity.
- Publish only after explicit user action.
- Daily and weekly challenges.
- Comments and peer feedback.
- Manual moderation, reports, and automated filters.
- Mixed content with age gating.

## Out of scope

- AI critique/feedback.
- Paid subscriptions or freemium template gates.
- Desktop/web editor.
- Professional editing suite features.
- Public-by-default posting.
- Automatic upload of private drafts without clear sync intent.

## MVP acceptance criteria

- User can authenticate with at least one launch auth method before community/sync use.
- User can create a project from a template.
- User can complete a guided shot sequence.
- User can import library clips for prompts.
- User can save and resume a draft offline.
- User can assemble, preview, and export a short no longer than 180 seconds.
- User can share/export to another app.
- User can publish only by explicit action.
- Published shorts can receive comments/feedback.
- Challenges exist for daily and weekly participation.
- Moderation/reporting paths exist before public community launch.

## Risks

- Auth + sync + community + offline export may be too large for first implementation pass.
- Camera and export now have production-shaped foundations, but physical-device and mixed-media fixture QA remain release gates.
- Community and mixed-content safety require policy and moderation before launch.
- Template count of 10 may slow launch unless template format is simple and data-driven.
