# Concerns

## Product/implementation gaps

- Generated app is not production complete.
- Camera path appears placeholder-like and needs real implementation or scope cut.
- Preview/export UI may overpromise compared with actual export behavior.
- Edit styles, transitions, title cards, trimming, and reorder UX need validation.
- Template count of 10 needs data-driven implementation to avoid hardcoded sprawl.

## Architecture risks

- `UserDefaults` persistence may be insufficient for media-heavy drafts.
- Sync/community/auth will require backend architecture not yet implemented.
- Offline editing plus conflict-safe sync is non-trivial.
- Moderation and age gating must exist before mixed public community launch.

## Verification gaps

- Tests are generated shells and do not cover product behavior yet.
- No Swift lint/format config.
- Linux baseline cannot run Xcode tests.

## Suggested first issues

1. Add unit tests for prompt generation and session lifecycle.
2. Decide/import-first vs real camera capture for MVP milestone.
3. Define launch template schema and first 10 templates.
4. Replace placeholder preview/export UX with verified behavior.
5. Draft backend/auth/sync architecture before community implementation.
