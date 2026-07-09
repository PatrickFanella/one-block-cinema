# Draft Persistence Plan

Issue: #15.

## Goal

Store local drafts safely for offline work without treating private media as synced/public content.

## Current state

- `SessionStorage` persists normalized project and clip metadata in a GRDB-managed SQLite database under app support.
- Imported videos are copied into `Application Support/OneBlockCinema/Drafts/{sessionId}/Media/`.
- Media owned by the app is stored as a path relative to the app-support root so container moves do not break drafts.
- Missing media is retained as an explicit `ClipMediaStatus.missing` record; unreadable legacy metadata is left in place and indexed in `recovery_issues`.
- My Films surfaces missing clips and opens the first affected shot for replacement. It also reports unreadable recovery records without discarding their source metadata.
- A storage audit identifies files under the private Drafts tree that are unreferenced and at least 24 hours old. Cleanup never traverses outside that tree and preserves every database-referenced clip and thumbnail.
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
5. If a media file is missing, retain the clip as a recoverable missing-media record, mark the film in My Films, and route resume to the first affected shot so capture/import can replace it.
6. Delete removes metadata and session media. User-initiated cleanup removes only stale, unreferenced files after a 24-hour in-flight-import grace period.

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

Persistence tests cover create/save/load/delete, relative media resolution, missing media, idempotent legacy migration, unreadable legacy metadata, and safe orphan cleanup.
