# Epic Plan

This plan maps each roadmap epic to Open Pilot-ready child issues and completion criteria. Epics are tracking containers; child issues carry scoped implementation and verification.

## Planning rules

- Keep every child issue independently shippable.
- Require `ready-for-agent`, acceptance criteria, deterministic test command, and out-of-scope notes.
- Do not add `agent:queued` until a human reviews the final issue body.
- Prefer local-first behavior. Sync/community must enhance creation, not block it.
- Use `make verify` for docs/planning issues unless a narrower deterministic command exists.

## Phase 0 — Alignment and scaffolding

Epic issue: #1. Related planning issue: #12. Master plan: #39.

Goal: make the generated app safe for agent work by aligning docs, scope, and verification.

Child work:

1. #12 Update planning docs to reflect issue roadmap decisions.
   - Acceptance: roadmap matches milestone sequence, MVP scope names current tradeoffs, Open Pilot expectations stay documented.
   - Test: `make verify`.
2. Keep generated placeholders visible in docs until replaced.
   - Acceptance: camera/export/editor limitations remain called out in `docs/codebase/CONCERNS.md` and `docs/codebase/ARCHITECTURE.md`.
   - Test: `make verify`.
3. Keep Linux verification green.
   - Acceptance: required docs/templates exist; no tracked secret files; Xcode checks remain explicitly macOS-only.
   - Test: `make verify`.

Completion: #1, #12, and #39 can close when this epic plan lands and verification passes. Product implementation remains out of scope for Phase 0.

## Phase 1 — Core foundations

Epic issue: #2. Child issues: #15, #17.

Goal: establish local creation basics: template-driven prompts, session lifecycle, and media-safe draft persistence.

Child work:

1. #15 Design draft persistence for media-safe local storage.
   - Acceptance: persistence plan covers metadata vs media files, migration from `UserDefaults`, save/load/delete behavior, offline recovery, and no automatic private draft upload.
   - Test: `make verify` for docs; future implementation should add model/storage tests.
2. #17 Implement template-driven prompt flow.
   - Acceptance: prompts are generated from template data, session state advances deterministically, current generated theme-only assumptions are removed or adapted.
   - Test: Swift unit tests on macOS when available; `make verify` remains Linux baseline.
3. Add lifecycle tests when implementation starts.
   - Acceptance: create session, advance prompt, attach clip placeholder, save/resume, complete session.
   - Test: `xcodebuild test -project ios/OneBlockCinema.xcodeproj -scheme OneBlockCinema -destination 'platform=iOS Simulator,name=iPhone 16'`.

Completion: close #2 only after #15 and #17 are closed or explicitly superseded by narrower implementation issues.

## Phase 2 — Minimal end-to-end slice

Epic issue: #3. Child issue: #22.

Goal: prove one complete local flow from project start to export/share without overpromising unsupported editor features.

Child work:

1. #22 Document first E2E flow and verification notes.
   - Acceptance: docs name the happy path, device/simulator assumptions, known placeholders, and verification limits.
   - Test: `make verify`.
2. Implement import-first capture path if real camera is not ready.
   - Acceptance: user can attach library clips to prompts; unsupported camera behavior is hidden or clearly labeled.
   - Test: Xcode unit/UI smoke tests when macOS runner exists.
3. Validate preview/export path.
   - Acceptance: exported video respects 180-second cap, share sheet opens only after successful export, failures are user-visible.
   - Test: AVFoundation export test with fixture clips on macOS.

Completion: close #3 only after #22 and the minimal create-to-export implementation issues pass verification.

## Phase 3 — Feature expansion

Epic issues: #4 and #5. Child issues: #23, #24, #25, #26, #27, #28, #29.

Goal: expand beyond the first slice into 10 templates, scoped editing, and backend contracts for auth/sync/community.

Template child work:

1. #23 Create launch catalog of 10 beginner templates.
   - Acceptance: every template has name, structure, prompt sequence, target duration, aspect ratio, and beginner coaching notes.
   - Test: `make verify` for docs/data; future schema tests when templates become code.
2. #24 Implement template picker.
   - Acceptance: user can choose among all 10 templates; selected template drives session prompts and targets.
   - Test: Xcode unit/UI tests.
3. #25 Implement only verified editing scope.
   - Acceptance: reorder and trim are supported only if functional; unsupported transitions/title-card claims are removed or marked future.
   - Test: Xcode tests for clip order, trim bounds, and export handoff.

Backend child work:

1. #26 Design backend architecture.
   - Acceptance: auth/session, sync, community, media storage, moderation, and privacy boundaries are documented.
   - Test: `make verify`.
2. #27 Specify auth API.
   - Acceptance: email OTP, Google, Apple, logout, token/session lifecycle, and error states are specified.
   - Test: `make verify`.
3. #28 Specify sync API.
   - Acceptance: projects, drafts, profile, community activity, conflict handling, and offline retries are specified.
   - Test: `make verify`.
4. #29 Specify community API.
   - Acceptance: challenges, submissions, comments, feedback, reporting, and publish permissions are specified.
   - Test: `make verify`.

Completion: close #4 after #23-#25 are complete. Close #5 after #26-#29 are complete. Backend implementation must not start until contracts and privacy defaults are accepted.

## Phase 4 — Quality hardening

Epic issue: #6. Child issues: #30, #31, #32, #33, #34.

Goal: harden privacy, safety, offline resilience, tests, and product observability before public community launch.

Child work:

1. #30 Harden privacy defaults.
   - Acceptance: drafts are private by default; publish requires explicit user action; sync never silently publishes.
   - Test: privacy state unit tests and `make verify`.
2. #31 Design moderation.
   - Acceptance: report flow, auto-filter boundary, manual queue, age gating, and escalation rules are documented.
   - Test: `make verify`.
3. #32 Harden offline mode.
   - Acceptance: draft save/resume/export failure states are recoverable and visible.
   - Test: storage/export tests on macOS plus `make verify`.
4. #33 Add coverage for core model/viewmodel/export guards.
   - Acceptance: session lifecycle, prompt generation, storage, duration cap, and export errors have tests.
   - Test: Xcode test command.
5. #34 Design privacy-safe analytics/observability.
   - Acceptance: metrics cover completion, export, retention, and community feedback without collecting private draft content.
   - Test: `make verify`.

Completion: close #6 only after privacy/moderation/offline/test/analytics child issues are closed.

## Phase 5 — Release and operations

Epic issue: #7. Child issues: #35, #36, #37.

Goal: prepare launch operations, App Store materials, and incident/moderation runbooks.

Child work:

1. #35 Create release checklist.
   - Acceptance: checklist covers build, signing, permissions, offline checks, export/share QA, privacy copy, and rollback/no-go criteria.
   - Test: `make verify`.
2. #36 Draft App Store copy and screenshots list.
   - Acceptance: copy matches MVP behavior and does not claim AI critique or professional editing features.
   - Test: `make verify`.
3. #37 Create operations runbooks.
   - Acceptance: moderation, reports, content incident, failed export, and support escalation basics exist.
   - Test: `make verify`.

Completion: close #7 only after #35-#37 are closed and MVP scope has no launch-blocking mismatch.

## Phase 6 — Post-MVP polish

Epic issue: #8. Child issue: #38.

Goal: reserve AI critique/coach feedback for after the MVP is stable.

Child work:

1. #38 Plan AI critique feedback coach.
   - Acceptance: plan defines user value, safety/privacy constraints, offline fallback, model/provider assumptions, and non-MVP status.
   - Test: `make verify`.

Completion: keep #8 open until post-MVP work is intentionally scheduled. Do not let #38 expand MVP scope.

## Thorough check

- Every phase has a clear goal, child issues, acceptance criteria, test command, and out-of-scope boundary.
- Phase order preserves dependencies: local creation before export polish, backend contracts before community, moderation before public launch, AI after MVP.
- Open Pilot requirements remain intact: `ready-for-agent`, deterministic `Test Command`, scoped acceptance criteria, explicit out-of-scope notes.
- Current implementation risks stay documented instead of hidden.
