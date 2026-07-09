# Generated app audit: current behavior vs MVP promise

This audit compares the generated iOS app shell with the MVP promise in `docs/product/PRD.md` and `docs/product/MVP_SCOPE.md`. It is a product/implementation alignment snapshot, not a release checklist.

## MVP promise baseline

- Core promise: a smartphone becomes a step-by-step filmmaking coach for structured 1–3 minute shorts (`docs/product/PRD.md:14-20`).
- Must-haves include auth, 10 launch templates, guided shot flow, capture/import, assembly up to 180 seconds, export/share, offline editing/export, sync, challenges, comments, and peer/community feedback (`docs/product/PRD.md:22-33`).
- The default flow includes login or draft resume, template/challenge selection, prompt-driven capture/import, review/reorder/trim, final preview, local export/share, optional publish, and private-until-publish community feedback (`docs/product/PRD.md:43-53`).
- MVP acceptance criteria require auth, project creation, guided shot completion, record/import, local draft resume, assemble/preview/export under 180 seconds, external share/export, explicit publish, comments/feedback, challenges, and moderation/reporting (`docs/product/MVP_SCOPE.md:55-67`).

## Implemented behavior

- The app has a local create/library shell with generated SwiftUI screens, feature state, and a GRDB-backed project store (`ios/OneBlockCinema/ContentView.swift`, `ios/OneBlockCinema/FilmSessionViewModel.swift`, `ios/OneBlockCinema/SessionStorage.swift`).
- Users can choose from 10 schema-validated bundled templates and start a local guided session (`ios/OneBlockCinema/HomeView.swift`, `ios/OneBlockCinema/Resources/FilmTemplates.json`).
- The template flow snapshots stable template-shot ids, timing, duration, aspect ratio, and guidance into each session and tracks guided progress (`ios/OneBlockCinema/TemplateModels.swift`, `ios/OneBlockCinema/FilmSession.swift`).
- Users can record with AVFoundation or import from Photos, review/retake, and attach the accepted durable copy to the current prompt (`ios/OneBlockCinema/CameraCapture.swift`, `ios/OneBlockCinema/CaptureView.swift`, `ios/OneBlockCinema/FilmSessionViewModel.swift`).
- Users can inspect/remove clips, set non-destructive in/out points, change the durable playback order, add clip title overlays, choose source-audio levels and a standard/silent-film look, and continue to preview/export (`ios/OneBlockCinema/AssemblyView.swift`, `ios/OneBlockCinema/FilmSessionViewModel.swift`).
- Users can play the assembled AVFoundation composition, export the same immutable render plan, cancel with live progress, and open a native share sheet (`ios/OneBlockCinema/PreviewExportView.swift`, `ios/OneBlockCinema/VideoExportService.swift`).
- Sessions can be saved, loaded, resumed, completed, and deleted through GRDB SQLite and relative app-support media paths, with idempotent legacy migration and missing-media recovery (`ios/OneBlockCinema/SessionStorage.swift`, `ios/OneBlockCinema/FilmSessionViewModel.swift`).

## Partial behavior

- Capture/import is production-shaped but not release-verified: native recording, import, prompt/aspect guides, focus/exposure, torch, zoom, stabilization, microphone control, rotation, and retake exist; physical-device interruption, thermal, storage, and permission QA remain incomplete.
- Template editorial/device QA remains incomplete even though all 10 launch templates now load from a versioned bundled catalog.
- Assembly/editing is partial: order, trim, title-overlay, source-volume, and standard/silent-film controls persist and feed the shared render plan, while crossfades, standalone intertitles, voiceover, ambient beds, and other pacing/style metadata are not yet a verified editor pipeline (`ios/OneBlockCinema/AssemblyView.swift`, `ios/OneBlockCinema/FilmSessionViewModel.swift`, `ios/OneBlockCinema/VideoExportService.swift`).
- Preview uses AVPlayer with the same orientation-normalized composition and template render dimensions as export. Fixture/device QA for HDR and variable-frame-rate sources remains incomplete (`ios/OneBlockCinema/PreviewExportView.swift`, `ios/OneBlockCinema/VideoExportService.swift`).
- Export/share is partial: local 1080p-class MP4 composition, saved order/trim/title/source-volume/look decisions, template aspect sizing, disk-space checks, cancellation, progress, a 180-second hard cap, and the share sheet exist; crossfades, standalone intertitles, voiceover/ambient tracks, and background interruption recovery are not complete (`ios/OneBlockCinema/VideoExportService.swift`, `ios/OneBlockCinema/PreviewExportView.swift`).
- Offline creation is partial: GRDB metadata, relative media paths, missing-media recovery, and schema migrations support durable resume, but recovery UI, storage cleanup, and conflict-aware sync remain future work (`ios/OneBlockCinema/SessionStorage.swift`, `docs/technical/DRAFT_PERSISTENCE.md`).

## Missing behavior

- Authentication is missing, including email OTP, Google, and Apple sign-in (`docs/product/PRD.md:24`, `docs/product/PRD.md:70-75`, `docs/product/MVP_SCOPE.md:9-14`).
- User-editable profiles are missing (`docs/product/PRD.md:61-68`, `docs/product/MVP_SCOPE.md:11-14`).
- Backend activation is missing: Fastify routes, worker queues, RLS schema, and the moderation console compile, but no environment or iOS auth/sync client is connected (`backend/`, `supabase/`, `moderation-console/`).
- Project/draft/profile/comment/challenge sync is missing (`docs/product/PRD.md:31`, `docs/product/PRD.md:70-75`, `docs/technical/API_SPEC.md:58-63`).
- Publish and private-until-publish flows are missing (`docs/product/PRD.md:52-53`, `docs/product/MVP_SCOPE.md:39-40`, `docs/technical/API_SPEC.md:9-13`).
- Daily/weekly challenges are missing (`docs/product/PRD.md:32`, `docs/product/PRD.md:61-68`, `docs/product/MVP_SCOPE.md:41`).
- Comments, reports, reciprocal blocks, moderation queues/actions, and age-gate constraints exist as inactive server/schema contracts; the iOS experience, automated moderation, policies, and operational drills are missing.
- Backend-delivered/versioned template updates are not implemented; the launch catalog is bundled and offline-only.
- Unit tests cover template, session, storage, and export-plan basics, but media fixture and meaningful UI-flow coverage remain missing (`docs/codebase/CONCERNS.md:19-23`).

## Overpromised behavior in the generated shell

- The "Preview & Export" / "Export & Share" flow suggests a complete assembly/export/share pipeline, but it only marks completion, exports locally, and opens the platform share sheet (`ios/OneBlockCinema/AssemblyView.swift:240-257`, `ios/OneBlockCinema/PreviewExportView.swift:153-176`, `ios/OneBlockCinema/VideoExportService.swift:41-60`).
- The iOS product remains local-only even though inactive backend/community foundations now exist; no local draft is uploaded without a future explicit sync flow.

## P0 blockers before connected/community release

1. **iOS authentication and sync clients are absent.** This blocks connected profiles, publishing, private-until-publish identity, comments, and community participation.
2. **External environments are unconfigured.** Separate Supabase/Mux/Fly projects, credentials, SMTP, APNs, backups, and restore drills are still required.
3. **Community safety is not operational.** RLS, reports, blocks, queues, manual review, and the admin console exist as foundations, but automated filtering, policy/runbook review, staffing, appeals, and end-to-end staging tests remain gates.
4. **Cloud media sync is absent.** The durable local GRDB store, outbox, relative media paths, and conflict recovery types are present, but resumable cloud transfer is not.
5. **Capture/edit/export still needs device and media-fixture hardening.** Camera plus trim/order/title/volume/look device QA, crossfades, standalone intertitles, voiceover/ambient tracks, and background export recovery remain incomplete; the shared preview/export render plan still needs representative-device and mixed-media QA (`ios/OneBlockCinema/CameraCapture.swift`, `ios/OneBlockCinema/PreviewExportView.swift`, `ios/OneBlockCinema/VideoExportService.swift`).
