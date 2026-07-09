# Draft Persistence Plan

Issue: #15.

## Goal

Store local drafts safely for offline work without treating private media as synced/public content.

## Current state

- `SessionStorage` persists normalized project and clip metadata in a GRDB-managed SQLite database under app support.
- Imported videos are copied into `Application Support/OneBlockCinema/Drafts/{sessionId}/Media/`.
- Media owned by the app is stored as a path relative to the app-support root so container moves do not break drafts.
- Missing media is retained as an explicit `ClipMediaStatus.missing` record; unreadable legacy metadata is left in place and indexed in `recovery_issues`.
- Legacy `sessions.json` and `UserDefaults` payloads are imported idempotently on first database access and are no longer mirrored after migration.
- The same database contains a durable `sync_outbox`; operations use their UUID as an idempotency key and retain retry state across launches.
- Drafts are local-first; sync is future work.

## Target design

- Store project metadata in SQLite `sessions` and `clips` tables, with encoded versioned session fields retained in the session payload.
- Store imported/captured media under `Application Support/OneBlockCinema/Drafts/{sessionId}/Media/`.
- Keep generated thumbnails under `Application Support/Drafts/{sessionId}/Thumbnails/`.
- Use relative paths in metadata so app-container moves do not break drafts.
- Keep private drafts off network until explicit sync/publish work is implemented.

## Lifecycle

1. Create session from `FilmTemplate`.
2. Copy imported/captured clip into the session media folder.
3. Persist metadata after each prompt completion, clip add/remove, pacing change, or export state change.
4. On resume, load metadata first and validate every referenced media file.
5. If a media file is missing, retain the clip as a recoverable missing-media record and keep the draft metadata editable. A dedicated repair UI remains future work.
6. Delete removes metadata and session media. Thumbnail and transient export ownership are future work.

## Migration

- Read existing `sessions.json` or `UserDefaults` sessions once.
- Write decodable sessions into SQLite without deleting the original legacy payload.
- Record undecodable sources in `recovery_issues` and mark the migration complete so a bad payload cannot block every launch.
- Mark clips whose files cannot be found as missing, not deleted.

## Acceptance mapping

- Metadata vs media files: defined above.
- Migration from `UserDefaults`: one-time copy, non-destructive.
- Save/load/delete: lifecycle steps defined.
- Offline recovery: durable media copy, missing-media state, and unreadable-metadata recovery records are implemented.
- Privacy: no automatic private draft upload.

## Test command

```bash
make verify
```

Persistence tests cover create/save/load/delete, relative media resolution, missing media, idempotent legacy migration, and unreadable legacy metadata.
