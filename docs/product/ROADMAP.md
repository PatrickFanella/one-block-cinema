# Production Roadmap

## 0.1 Internal alpha — offline creator

Implemented foundations:

- Deterministic portable/macOS CI, check-only SwiftFormat/SwiftLint, unsigned archive validation, and Fastlane release lanes.
- Ten versioned, schema-validated bundled templates.
- GRDB projects/clips, relative media paths, idempotent legacy migration, missing-media recovery records, and durable sync outbox.
- Real AVPlayer preview and cancellable, orientation-normalized 1080p-class MP4 export from one `RenderPlan` with audio preservation, disk checks, and the 180-second cap.
- Import-first fallback remains fully offline and account-free.

Remaining gates:

- Execute simulator tests after repairing the host CoreSimulator mismatch.
- Add representative media fixtures, background interruption recovery, storage cleanup, and a user-facing repair flow.
- Verify all templates end to end on physical devices.

## 0.5 External TestFlight — filmmaking toolkit

Implemented foundation:

- AVFoundation 1080p camera recording, front/rear cameras, tap focus/exposure, torch, bounded zoom, automatic stabilization, microphone control, prompt/aspect overlays, rotation, a 180-second recording cap, retake review, Settings recovery, and equal Photos import.
- Non-destructive in/out trim points and user-controlled clip order persist in GRDB and drive the shared preview/export render plan.
- Straight cuts and pacing-aware crossfades, clip title overlays, per-clip source-audio levels, and selectable standard/silent-film looks render identically in preview and export.

Remaining:

- Standalone title/intertitle cards, voiceover, ambient beds, and additional audio tracks.
- VoiceOver, Dynamic Type, reduced-motion, contrast, keyboard, localization, and oldest-device audits.

## 1.0 Creator launch — accounts and sync

Implemented foundation:

- Provider-neutral auth/sync/community protocols, revision state, non-destructive recovered-copy conflict policy, Fastify API, pg-boss worker, Supabase schema/RLS, private storage policies, and environment/deployment runbook.
- Fail-closed iOS environment/feature configuration, a validated local-only Apple privacy manifest, and draft privacy, terms, support, retention, and App Store disclosure artifacts.

Remaining:

- Provision separate development/staging/production Supabase and Fly environments.
- Connect native OTP/Apple/Google auth and Keychain session storage.
- Build opt-in project/original-media sync with resumable checksummed transfer and visible retry state.
- Complete profile, export, logout/revocation, in-app account deletion, approve/finalize legal placeholders, backups, restore drills, rate limits, abuse protection, observability, and incident runbooks.
- Ship with community flags disabled.

## 1.1 Community — curated challenges

Implemented foundation:

- RLS tables/policies for challenges, publications, comments, reports, reciprocal blocks, teen-private safety data, moderation queues/actions, feature flags, signed Mux webhook verification, and an admin-role moderation console.

Remaining:

- Mux direct upload/signed playback, frame/audio extraction, automated text/image moderation, manual review operations, APNs, appeals/takedowns, staffing, and staged rollout drills.
- The community flag remains off until all safety and App Review gates pass.

## 1.2 AI Coach — explicit opt-in

Only provider-neutral types and a disabled endpoint exist. Provider credentials and calls are intentionally unconfigured. Consent UX, minimized media sampling, moderation, structured critique, retention controls, evals, safety review, cost/latency thresholds, and staged rollout all remain required.

## Release thresholds

- No open P0/P1 security or data-loss defects.
- At least 14 stable TestFlight days with 50 external testers.
- Crash-free sessions at least 99.5%; supported-media export success at least 98%.
- API availability at least 99.9% with non-media p95 below 500 ms.
- Publication processing success at least 99% with p95 below five minutes.
- Successful backup/restore rehearsal and exercised privacy, moderation, support, App Review, and incident runbooks.
