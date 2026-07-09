# Concerns

## Product/implementation gaps

- Focused audit: `docs/codebase/GENERATED_APP_AUDIT.md` documents implemented, partial, missing, and overpromised behavior with file references and P0 blockers.
- Generated app is not production complete.
- Camera path appears placeholder-like and is cut from MVP in favor of import-first capture.
- Preview and export now share one render plan, but representative-device and HDR/variable-frame-rate fixture QA remain outstanding.
- Edit styles, transitions, title cards, trimming, and reorder UX need validation.
- Ten templates now load from a versioned bundled catalog; editorial, device, and accessibility QA remain incomplete.

## Architecture risks

- Draft persistence now uses GRDB, relative paths, and missing-media recovery; a user-facing repair workflow and storage-pressure cleanup policy remain incomplete.
- Backend/RLS/service boundaries exist, but iOS auth, resumable media sync, environment provisioning, and operational validation are not implemented.
- Offline editing plus conflict-safe sync is non-trivial.
- Moderation and age gating must exist before mixed public community launch.

## Verification gaps

- Unit tests cover template/prompt/session basics and persistence migration/recovery, but do not yet cover real media import/export or UI behavior.
- Swift lint/format configuration exists; the tools remain optional locally and required on the macOS CI runner.
- Linux baseline cannot run Xcode tests.

## Suggested first issues

1. Add unit tests for prompt generation and session lifecycle.
2. Implement and verify import-first prompt clip attachment.
3. Verify all 10 templates end-to-end with representative media and device accessibility QA.
4. Replace or clearly disable placeholder camera UX until a post-MVP camera issue.
5. Replace placeholder preview/export UX with verified behavior.
6. Connect native auth and project sync only after disposable-environment RLS tests pass.
