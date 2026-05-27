# Generated app audit: current behavior vs MVP promise

This audit compares the generated iOS app shell with the MVP promise in `docs/product/PRD.md` and `docs/product/MVP_SCOPE.md`. It is a product/implementation alignment snapshot, not a release checklist.

## MVP promise baseline

- Core promise: a smartphone becomes a step-by-step filmmaking coach for structured 1–3 minute shorts (`docs/product/PRD.md:14-20`).
- Must-haves include auth, 10 launch templates, guided shot flow, capture/import, assembly up to 180 seconds, export/share, offline editing/export, sync, challenges, comments, and peer/community feedback (`docs/product/PRD.md:22-33`).
- The default flow includes login or draft resume, template/challenge selection, prompt-driven capture/import, review/reorder/trim, final preview, local export/share, optional publish, and private-until-publish community feedback (`docs/product/PRD.md:43-53`).
- MVP acceptance criteria require auth, project creation, guided shot completion, record/import, local draft resume, assemble/preview/export under 180 seconds, external share/export, explicit publish, comments/feedback, challenges, and moderation/reporting (`docs/product/MVP_SCOPE.md:55-67`).

## Implemented behavior

- The app has a local create/library shell with generated SwiftUI screens and in-memory view model state (`ios/ContentView.swift:7-25`, `ios/OneBlockCinema/FilmSessionViewModel.swift:7-21`).
- Users can choose from existing genre cards and start a local guided session (`ios/OneBlockCinema/HomeView.swift:102-125`, `ios/OneBlockCinema/FilmSessionViewModel.swift:42-51`).
- The generated template flow creates prompt sequences and tracks guided shot progress (`ios/OneBlockCinema/PromptGenerator.swift:3-72`, `ios/OneBlockCinema/ShotSequenceView.swift:12-64`, `ios/OneBlockCinema/FilmSession.swift:39-50`).
- Users can import a video from the Photos library and attach it to the current prompt (`ios/OneBlockCinema/CaptureView.swift:39-43`, `ios/OneBlockCinema/CaptureView.swift:191-205`, `ios/OneBlockCinema/FilmSessionViewModel.swift:81-89`).
- Users can review a clip list, inspect clip details, remove clips, toggle title cards, edit title text, choose pacing/style, and toggle captured-audio soundtrack metadata (`ios/OneBlockCinema/AssemblyView.swift:48-258`, `ios/OneBlockCinema/AssemblyView.swift:260-314`, `ios/OneBlockCinema/FilmSessionViewModel.swift:91-129`).
- Users can open a preview/export screen, step through clips, start/stop simple auto-advance playback, export via AVFoundation, and open a native share sheet (`ios/OneBlockCinema/PreviewExportView.swift:40-49`, `ios/OneBlockCinema/PreviewExportView.swift:53-187`, `ios/OneBlockCinema/PreviewExportView.swift:189-232`, `ios/OneBlockCinema/VideoExportService.swift:4-61`).
- Sessions can be saved, loaded, resumed, completed, and deleted locally through `UserDefaults` storage (`ios/OneBlockCinema/SessionStorage.swift:3-18`, `ios/OneBlockCinema/FilmSessionViewModel.swift:38-57`, `ios/OneBlockCinema/FilmSessionViewModel.swift:150-180`).

## Partial behavior

- Capture/import is partial: library import works, but the camera surface is a placeholder and the record button has no recording implementation (`ios/OneBlockCinema/CaptureView.swift:82-109`, `ios/OneBlockCinema/CaptureView.swift:146-189`). This falls short of the record-or-import requirement (`docs/product/MVP_SCOPE.md:22-26`, `docs/product/MVP_SCOPE.md:60`).
- Template coverage is partial: the app ships five hardcoded themes, while MVP calls for 10 launch templates with duration/aspect/shot-count metadata (`ios/OneBlockCinema/FilmTheme.swift:3-8`, `docs/product/PRD.md:55-59`, `docs/product/MVP_SCOPE.md:15-20`).
- Assembly/editing is partial: clip order mutation, title metadata, pacing/style choices, and soundtrack metadata exist, but there is no trim UI and the style/pacing controls are not a verified editor pipeline (`ios/OneBlockCinema/AssemblyView.swift:121-258`, `ios/OneBlockCinema/FilmSessionViewModel.swift:99-129`, `docs/product/MVP_SCOPE.md:28-35`).
- Preview is partial: it displays symbolic clip cards and a timed clip stepper rather than actual rendered playback of the assembled video (`ios/OneBlockCinema/PreviewExportView.swift:53-116`, `ios/OneBlockCinema/PreviewExportView.swift:189-221`, `docs/product/MVP_SCOPE.md:32`).
- Export/share is partial: a local MP4 export and share sheet exist, but the code does not enforce the MVP 180-second hard cap or surface social-platform target requirements (`ios/OneBlockCinema/VideoExportService.swift:16-60`, `ios/OneBlockCinema/PreviewExportView.swift:153-176`, `docs/product/PRD.md:28-30`, `docs/product/MVP_SCOPE.md:33-35`).
- Offline creation is partial: local `UserDefaults` persistence supports basic resume, but the documented offline/sync model requires robust local drafts plus resumable, conflict-aware sync (`ios/OneBlockCinema/SessionStorage.swift:3-18`, `docs/technical/API_SPEC.md:58-63`).

## Missing behavior

- Authentication is missing, including email OTP, Google, and Apple sign-in (`docs/product/PRD.md:24`, `docs/product/PRD.md:70-75`, `docs/product/MVP_SCOPE.md:9-14`).
- User-editable profiles are missing (`docs/product/PRD.md:61-68`, `docs/product/MVP_SCOPE.md:11-14`).
- Backend API implementation is missing; the API spec explicitly says backend is planned, not implemented (`docs/technical/API_SPEC.md:3-13`).
- Project/draft/profile/comment/challenge sync is missing (`docs/product/PRD.md:31`, `docs/product/PRD.md:70-75`, `docs/technical/API_SPEC.md:58-63`).
- Publish and private-until-publish flows are missing (`docs/product/PRD.md:52-53`, `docs/product/MVP_SCOPE.md:39-40`, `docs/technical/API_SPEC.md:9-13`).
- Daily/weekly challenges are missing (`docs/product/PRD.md:32`, `docs/product/PRD.md:61-68`, `docs/product/MVP_SCOPE.md:41`).
- Comments, peer feedback, reports, moderation queue/actions, and age gating are missing (`docs/product/PRD.md:33`, `docs/product/PRD.md:61-68`, `docs/product/MVP_SCOPE.md:42-44`, `docs/technical/API_SPEC.md:45-56`).
- A data-driven launch template schema with duration targets, aspect ratios, shot counts, and assembly guidance is missing (`docs/product/PRD.md:55-59`, `docs/product/MVP_SCOPE.md:17-20`).
- Product behavior tests are missing; current verification notes say Linux skips Xcode tests and generated tests do not cover product behavior yet (`docs/codebase/CONCERNS.md:19-23`).

## Overpromised behavior in the generated shell

- The capture screen labels a "Camera Preview" and shows a red record control, but the implementation is a placeholder and does not record video (`ios/OneBlockCinema/CaptureView.swift:82-109`, `ios/OneBlockCinema/CaptureView.swift:172-189`).
- The preview screen appears to preview a final short, but the UI is a static symbolic clip display with timer-based clip advancement, not playback of the exported composition (`ios/OneBlockCinema/PreviewExportView.swift:53-116`, `ios/OneBlockCinema/PreviewExportView.swift:189-221`).
- The "Preview & Export" / "Export & Share" flow suggests a complete assembly/export/share pipeline, but it only marks completion, exports locally, and opens the platform share sheet (`ios/OneBlockCinema/AssemblyView.swift:240-257`, `ios/OneBlockCinema/PreviewExportView.swift:153-176`, `ios/OneBlockCinema/VideoExportService.swift:41-60`).
- Genre selection suggests broad template coverage, but only five hardcoded themes are available against the 10-template MVP target (`ios/OneBlockCinema/HomeView.swift:102-125`, `ios/OneBlockCinema/FilmTheme.swift:3-8`, `docs/product/PRD.md:24-25`).
- The product promise includes community feedback and sync, but the current app is a local-only shell with no backend/auth/community implementation (`docs/product/PRD.md:18-33`, `docs/technical/API_SPEC.md:3-13`, `ios/OneBlockCinema/SessionStorage.swift:3-18`).

## P0 blockers before MVP implementation work

1. **Backend/auth/sync architecture is absent.** MVP requires auth, sync, publish, community, challenges, comments, moderation, and age gating, while the API spec is only planned (`docs/product/PRD.md:70-85`, `docs/technical/API_SPEC.md:3-13`).
2. **No authentication path exists.** This blocks sync, publishing, private-until-publish identity, comments, and community participation (`docs/product/PRD.md:24`, `docs/product/PRD.md:72-74`, `docs/product/MVP_SCOPE.md:57`).
3. **No publish/community safety path exists.** Publish, comments, reports, moderation, and age gating must be defined before any public community launch (`docs/product/PRD.md:61-68`, `docs/product/MVP_SCOPE.md:64-67`, `docs/technical/API_SPEC.md:39-56`).
4. **Template model is under-scoped.** The app has five hardcoded themes, but MVP requires 10 templates with duration/aspect/shot-count/assembly guidance (`ios/OneBlockCinema/FilmTheme.swift:3-8`, `docs/product/PRD.md:55-59`).
5. **Capture/preview/export claims need productization or explicit scope cuts.** Camera recording, true final preview playback, trim support, and 180-second enforcement are not complete enough to satisfy the MVP acceptance criteria (`ios/OneBlockCinema/CaptureView.swift:172-189`, `ios/OneBlockCinema/PreviewExportView.swift:53-116`, `ios/OneBlockCinema/VideoExportService.swift:16-60`, `docs/product/MVP_SCOPE.md:60-63`).
