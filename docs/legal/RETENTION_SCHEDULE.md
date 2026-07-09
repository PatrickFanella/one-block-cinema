# Data retention schedule

Status: operational draft — counsel and processor-contract review required.

| Data | Default retention | Deletion trigger | Notes |
|---|---|---|---|
| Local draft metadata and app-owned media | Until user deletes the project/app | Project or app deletion | No silent upload. |
| Private synced projects and original media | While project/account is active | Project deletion or account deletion | Define backup expiry before sync launch. |
| Exported files in app temporary storage | Short-lived; clear after handoff and routine cleanup | Successful share, cancellation, or cleanup | User-selected external copies are outside app control. |
| Authentication/session/device records | Active session plus limited security window | Logout, revocation, or account deletion | Exact window requires provider configuration. |
| Publications, comments, and profile UGC | Until user deletion, moderation removal, or account deletion | Relevant deletion action | Propagate deletion to Mux and caches. |
| Reports and moderation evidence | `[30–180 DAYS BY SEVERITY]` | Case closure plus approved evidence window | Access restricted; litigation/safety holds documented. |
| Moderator audit actions | `[AUDIT RETENTION PERIOD]` | Approved expiry | Append-only and admin-only. |
| Operational/security logs | `[30–90 DAYS]` | Automated expiry | Exclude raw media, filenames, prompt text, and freeform UGC. |
| AI temporary frames/audio | Process duration only | Immediately after response/failure | Provider abuse-monitoring retention disclosed separately. |
| AI critique result | Until user/project deletion or explicit result deletion | Relevant deletion action | Per-film consent record retained only as legally necessary. |
| Backups | `[BACKUP WINDOW]` | Scheduled expiry after primary deletion | Restore process must preserve tombstones. |

Account deletion must revoke sessions and Apple tokens, remove or irreversibly anonymize associated UGC as policy requires, delete private media and playback access, enqueue provider cleanup, and expose retry/audit status. The current server worker records external cleanup as pending; that is not a completed deletion implementation.
