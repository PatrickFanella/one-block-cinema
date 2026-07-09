# Structure

## Root

- `README.md` — project overview and quick start.
- `AGENTS.md` — agent/development instructions.
- `PLAN.md` — original Rork/generated product plan.
- `Makefile` — verification entrypoint.
- `rork.json` — Rork app registry.
- `.gitea/` — Open Pilot issue/PR/workflow templates.
- `docs/` — product, technical, and codebase docs.
- `ios/` — generated native iOS app.

## Product content

- `ios/OneBlockCinema/Resources/FilmTemplates.json` — the single bundled catalog of 10 production templates.
- `ios/OneBlockCinema/Resources/FilmTemplateV1.schema.json` — the versioned machine-readable template contract.

## iOS app

- `ios/OneBlockCinema/OneBlockCinemaApp.swift` — SwiftUI app entry.
- `ios/OneBlockCinema/ContentView.swift` — top-level tab/navigation shell.
- `ios/OneBlockCinema/` — app models, services, and views.
- `ios/OneBlockCinemaTests/` — unit test target.
- `ios/OneBlockCinemaUITests/` — UI test target.
- `ios/OneBlockCinema.xcodeproj/project.pbxproj` — Xcode project settings.

## App feature files

- `HomeView.swift` — template/session start.
- `ShotSequenceView.swift` — prompt sequence guidance.
- `CaptureView.swift` — clip capture/import screen.
- `AssemblyView.swift` — assembly/timeline screen.
- `PreviewExportView.swift` — preview/export screen.
- `MyFilmsView.swift` — saved session gallery.

## Domain/service files

- `FilmSession.swift`, `FilmClip.swift`, `ShotPrompt.swift` — core data models.
- `FilmTheme.swift`, `PacingStyle.swift`, `EditStyle.swift` — domain options.
- `FilmSessionViewModel.swift` — workflow state hub.
- `PromptGenerator.swift` — theme prompt generation.
- `SessionStorage.swift` — local persistence.
- `VideoExportService.swift` — AVFoundation export.

## UI utility files

- `CinemaColors.swift` — color palette.
- `FilmGrainView.swift` — visual texture overlay.
