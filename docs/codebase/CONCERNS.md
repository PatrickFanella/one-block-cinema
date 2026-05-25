# Concerns

## Product/implementation gaps

- Focused audit: `docs/codebase/GENERATED_APP_AUDIT.md` documents implemented, partial, missing, and overpromised behavior with file references and P0 blockers.
- Generated app is not production complete.
- Camera path appears placeholder-like and is cut from MVP in favor of import-first capture.
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
2. Implement and verify import-first prompt clip attachment.
3. Define launch template schema and first 10 templates.
4. Replace or clearly disable placeholder camera UX until a post-MVP camera issue.
5. Replace placeholder preview/export UX with verified behavior.
6. Draft backend/auth/sync architecture before community implementation.
