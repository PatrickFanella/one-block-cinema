# Concerns

## Product/implementation gaps

- Focused audit: `docs/codebase/GENERATED_APP_AUDIT.md` documents implemented, partial, missing, and overpromised behavior with file references and P0 blockers.
- Generated app is not production complete.
- Camera capture compiles with permission recovery and import fallback, but physical-device rotation, interruption, thermal, focus, stabilization, and audio QA remain outstanding.
- Preview and export now share one render plan with durable interruption checkpoints, but representative-device, background-expiration, and HDR/variable-frame-rate fixture QA remain outstanding.
- Durable trim/reorder, cuts/crossfades, clip titles/volume, project voiceover/ambient tracks, and standard/silent-film looks now feed preview and export, but need physical-device accessibility and representative-media validation; standalone intertitles remain incomplete.
- Ten templates now load from a versioned bundled catalog; editorial, device, and accessibility QA remain incomplete.

## Architecture risks

- Draft persistence now uses GRDB, relative paths, missing-media routing, and conservative orphan cleanup; low-storage interruption policy and support tooling for unreadable legacy records remain incomplete.
- Backend/RLS/service boundaries exist, but iOS auth, resumable media sync, environment provisioning, and operational validation are not implemented.
- The privacy manifest matches the local-only build; legal documents still contain owner/contact/retention placeholders and connected features require a new disclosure review.
- Offline editing plus conflict-safe sync is non-trivial.
- Moderation and age gating must exist before mixed public community launch.

## Verification gaps

- Unit tests cover template/prompt/session basics and persistence migration/recovery, but do not yet cover real media import/export or UI behavior.
- Swift lint/format configuration exists; the tools remain optional locally and required on the macOS CI runner.
- Linux baseline cannot run Xcode tests.

## Suggested first issues

1. Run camera/import prompt attachment on the oldest supported iPhone and representative modern devices.
2. Verify all 10 templates end-to-end with representative media and device accessibility QA.
3. Add deterministic camera interruption and low-storage recovery tests.
4. Exercise trim/order persistence and render output with mixed-orientation, HDR, variable-frame-rate, silent, and corrupt fixtures.
5. Connect native auth and project sync only after disposable-environment RLS tests pass.
