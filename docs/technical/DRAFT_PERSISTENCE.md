# Draft Persistence Plan

Issue: #15.

## Goal

Store local drafts safely for offline work without treating private media as synced/public content.

## Current state

- `SessionStorage` persists encoded `FilmSession` metadata to app support JSON and mirrors it to `UserDefaults` for legacy compatibility.
- Imported videos are copied into `Application Support/OneBlockCinema/Drafts/{sessionId}/Media/`.
- `FilmClip.fileURL` currently stores absolute local file URLs; relative paths remain a future hardening step for app-container moves.
- Drafts are local-first; sync is future work.

## Target design

- Store draft metadata as JSON under app support.
- Store imported/captured media under `Application Support/OneBlockCinema/Drafts/{sessionId}/Media/`.
- Keep generated thumbnails under `Application Support/Drafts/{sessionId}/Thumbnails/`.
- Use relative paths in metadata so app-container moves do not break drafts. *(Future hardening; current implementation stores durable absolute app-support URLs.)*
- Keep private drafts off network until explicit sync/publish work is implemented.

## Lifecycle

1. Create session from `FilmTemplate`.
2. Copy imported/captured clip into the session media folder.
3. Persist metadata after each prompt completion, clip add/remove, pacing change, or export state change.
4. On resume, load metadata first. Missing-media validation is future hardening.
5. If a media file is missing, show recoverable error and keep the draft editable. *(Future hardening.)*
6. Delete removes metadata and session media. Thumbnail and transient export ownership are future work.

## Migration

- Read existing `UserDefaults` sessions once.
- Write them to app support metadata files.
- Keep original data until migration completes.
- Mark clips whose media URLs cannot be copied as missing, not deleted.

## Acceptance mapping

- Metadata vs media files: defined above.
- Migration from `UserDefaults`: one-time copy, non-destructive.
- Save/load/delete: lifecycle steps defined.
- Offline recovery: durable media copy is implemented; explicit missing-media state is future hardening.
- Privacy: no automatic private draft upload.

## Test command

```bash
make verify
```

Future macOS implementation tests should cover create/save/load/delete/missing-media migration.
