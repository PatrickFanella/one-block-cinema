# Generated app audit: current behavior vs MVP promise

This audit compares the generated iOS app shell with the MVP promise in `docs/product/PRD.md` and `docs/product/MVP_SCOPE.md`. It is a product/implementation alignment snapshot, not a release checklist.

## MVP promise baseline

- Core promise: a smartphone becomes a step-by-step filmmaking coach for structured 1–3 minute shorts (`docs/product/PRD.md:14-20`).
- Must-haves include auth, 10 launch templates, guided shot flow, capture/import, assembly up to 180 seconds, export/share, offline editing/export, sync, challenges, comments, and peer/community feedback (`docs/product/PRD.md:22-33`).
- The default flow includes login or draft resume, template/challenge selection, prompt-driven capture/import, review/reorder/trim, final preview, local export/share, optional publish, and private-until-publish community feedback (`docs/product/PRD.md:43-53`).
- MVP acceptance criteria require auth, project creation, guided shot completion, record/import, local draft resume, assemble/preview/export under 180 seconds, external share/export, explicit publish, comments/feedback, challenges, and moderation/reporting (`docs/product/MVP_SCOPE.md:55-67`).

## Implemented behavior

- The app has a local create/library shell with generated SwiftUI screens and in-memory view model state (`ios/ContentView.swift:7-25`, `ios/OneBlockCinema/FilmSessionViewModel.swift:7-21`).
- Users can choose from 10 schema-validated bundled templates and start a local guided session (`ios/OneBlockCinema/HomeView.swift`, `ios/OneBlockCinema/Resources/FilmTemplates.json`).
- The template flow snapshots stable template-shot ids, timing, duration, aspect ratio, and guidance into each session and tracks guided progress (`ios/OneBlockCinema/TemplateModels.swift`, `ios/OneBlockCinema/FilmSession.swift`).
- Users can import a video from the Photos library and attach it to the current prompt (`ios/OneBlockCinema/CaptureView.swift:39-43`, `ios/OneBlockCinema/CaptureView.swift:191-205`, `ios/OneBlockCinema/FilmSessionViewModel.swift:81-89`).
- Users can review prompt-order clips, inspect clip details, remove clips, and continue to preview/export. Editing metadata exists in the model, but editing controls remain deliberately unavailable (`ios/OneBlockCinema/AssemblyView.swift`, `ios/OneBlockCinema/FilmSessionViewModel.swift`).
- Users can open a preview/export screen, step through clips, start/stop simple auto-advance playback, export via AVFoundation, and open a native share sheet (`ios/OneBlockCinema/PreviewExportView.swift:40-49`, `ios/OneBlockCinema/PreviewExportView.swift:53-187`, `ios/OneBlockCinema/PreviewExportView.swift:189-232`, `ios/OneBlockCinema/VideoExportService.swift:4-61`).
- Sessions can be saved, loaded, resumed, completed, and deleted through GRDB SQLite and relative app-support media paths, with idempotent legacy migration and missing-media recovery (`ios/OneBlockCinema/SessionStorage.swift`, `ios/OneBlockCinema/FilmSessionViewModel.swift`).

## Partial behavior

- Capture/import is partial: library import works, but the camera surface is a placeholder and the record button has no recording implementation (`ios/OneBlockCinema/CaptureView.swift:82-109`, `ios/OneBlockCinema/CaptureView.swift:146-189`). This falls short of the record-or-import requirement (`docs/product/MVP_SCOPE.md:22-26`, `docs/product/MVP_SCOPE.md:60`).
- Template editorial/device QA remains incomplete even though all 10 launch templates now load from a versioned bundled catalog.
- Assembly/editing is partial: clip order mutation, title metadata, pacing/style choices, and soundtrack metadata exist, but there is no trim UI and the style/pacing controls are not a verified editor pipeline (`ios/OneBlockCinema/AssemblyView.swift:121-258`, `ios/OneBlockCinema/FilmSessionViewModel.swift:99-129`, `docs/product/MVP_SCOPE.md:28-35`).
- Preview is partial: it displays symbolic clip cards and a timed clip stepper rather than actual rendered playback of the assembled video (`ios/OneBlockCinema/PreviewExportView.swift:53-116`, `ios/OneBlockCinema/PreviewExportView.swift:189-221`, `docs/product/MVP_SCOPE.md:32`).
- Export/share is partial: local MP4 concatenation, a 180-second hard cap, and the share sheet exist, but orientation normalization, real rendered preview, transitions, titles, and template-specific render sizing are not complete (`ios/OneBlockCinema/VideoExportService.swift`, `ios/OneBlockCinema/PreviewExportView.swift`).
- Offline creation is partial: GRDB metadata, relative media paths, missing-media recovery, and schema migrations support durable resume, but recovery UI, storage cleanup, and conflict-aware sync remain future work (`ios/OneBlockCinema/SessionStorage.swift`, `docs/technical/DRAFT_PERSISTENCE.md`).

## Missing behavior

- Authentication is missing, including email OTP, Google, and Apple sign-in (`docs/product/PRD.md:24`, `docs/product/PRD.md:70-75`, `docs/product/MVP_SCOPE.md:9-14`).
- User-editable profiles are missing (`docs/product/PRD.md:61-68`, `docs/product/MVP_SCOPE.md:11-14`).
- Backend API implementation is missing; the API spec explicitly says backend is planned, not implemented (`docs/technical/API_SPEC.md:3-13`).
- Project/draft/profile/comment/challenge sync is missing (`docs/product/PRD.md:31`, `docs/product/PRD.md:70-75`, `docs/technical/API_SPEC.md:58-63`).
- Publish and private-until-publish flows are missing (`docs/product/PRD.md:52-53`, `docs/product/MVP_SCOPE.md:39-40`, `docs/technical/API_SPEC.md:9-13`).
- Daily/weekly challenges are missing (`docs/product/PRD.md:32`, `docs/product/PRD.md:61-68`, `docs/product/MVP_SCOPE.md:41`).
- Comments, peer feedback, reports, moderation queue/actions, and age gating are missing (`docs/product/PRD.md:33`, `docs/product/PRD.md:61-68`, `docs/product/MVP_SCOPE.md:42-44`, `docs/technical/API_SPEC.md:45-56`).
- Backend-delivered/versioned template updates are not implemented; the launch catalog is bundled and offline-only.
- Unit tests cover template, session, storage, and export-plan basics, but media fixture and meaningful UI-flow coverage remain missing (`docs/codebase/CONCERNS.md:19-23`).

## Overpromised behavior in the generated shell

- The capture screen labels a "Camera Preview" and shows a red record control, but the implementation is a placeholder and does not record video (`ios/OneBlockCinema/CaptureView.swift:82-109`, `ios/OneBlockCinema/CaptureView.swift:172-189`).
- The preview screen appears to preview a final short, but the UI is a static symbolic clip display with timer-based clip advancement, not playback of the exported composition (`ios/OneBlockCinema/PreviewExportView.swift:53-116`, `ios/OneBlockCinema/PreviewExportView.swift:189-221`).
- The "Preview & Export" / "Export & Share" flow suggests a complete assembly/export/share pipeline, but it only marks completion, exports locally, and opens the platform share sheet (`ios/OneBlockCinema/AssemblyView.swift:240-257`, `ios/OneBlockCinema/PreviewExportView.swift:153-176`, `ios/OneBlockCinema/VideoExportService.swift:41-60`).
- The product promise includes community feedback and sync, but the current app is a local-only shell with no backend/auth/community implementation (`docs/product/PRD.md:18-33`, `docs/technical/API_SPEC.md:3-13`, `ios/OneBlockCinema/SessionStorage.swift:3-18`).

## P0 blockers before MVP implementation work

1. **Backend/auth/sync architecture is absent.** MVP requires auth, sync, publish, community, challenges, comments, moderation, and age gating, while the API spec is only planned (`docs/product/PRD.md:70-85`, `docs/technical/API_SPEC.md:3-13`).
2. **No authentication path exists.** This blocks sync, publishing, private-until-publish identity, comments, and community participation (`docs/product/PRD.md:24`, `docs/product/PRD.md:72-74`, `docs/product/MVP_SCOPE.md:57`).
3. **No publish/community safety path exists.** Publish, comments, reports, moderation, and age gating must be defined before any public community launch (`docs/product/PRD.md:61-68`, `docs/product/MVP_SCOPE.md:64-67`, `docs/technical/API_SPEC.md:39-56`).
4. **Sync architecture is absent.** The durable local GRDB store, relative media paths, and recovery records are now present, but resumable cloud media transfer and conflict-aware sync are not.
5. **Capture/preview/export claims need productization or explicit scope cuts.** Camera recording, true rendered preview playback, trim support, and normalized aspect-ratio export are not complete enough to satisfy the production roadmap (`ios/OneBlockCinema/CaptureView.swift`, `ios/OneBlockCinema/PreviewExportView.swift`, `ios/OneBlockCinema/VideoExportService.swift`).
