# Account deletion runbook

## Automated flow

`DELETE /v1/account` requires an authenticated user, a UUID idempotency key, and server-side Supabase admin configuration. It creates or requeues one durable `account_deletion` job per user and returns `202`.

The worker performs retry-safe cleanup in this order:

1. Mark the durable job `processing` and load private Storage paths, Mux asset ids, and identity providers.
2. Revoke Sign in with Apple when an approved revoker is configured. Until then, Apple accounts fail closed before any destructive step.
3. Remove private-draft objects through the Supabase Storage API in batches.
4. Delete Mux assets; missing assets are treated as already deleted.
5. Delete the Supabase Auth user; database rows cascade while the deletion job keeps its audit state with a null user reference.
6. Mark the durable job `completed`.

Provider failures mark the job `failed` with a bounded machine-readable code and are retried by pg-boss. The order preserves database resource ids until external cleanup succeeds. Provider 404 responses are treated as success so a crash between steps can be retried safely.

## Failure codes

- `apple_revocation_unconfigured`
- `storage_cleanup_unconfigured` / `storage_cleanup_failed`
- `mux_cleanup_unconfigured` / `mux_cleanup_failed`
- `auth_cleanup_unconfigured` / `auth_cleanup_failed`
- `provider_cleanup_failed`

## Operator response

1. Confirm the job id, failure code, attempt count, and affected environment without copying media paths or credentials into a ticket.
2. Verify provider status and server secret presence. Never expose service-role, Mux, or Apple credentials to the client.
3. For Mux/Storage 404s, allow the normal retry; they are idempotent successes.
4. For Apple accounts, do not bypass the fail-closed gate. Finish token capture/revocation configuration and its staging test first.
5. Requeue the same durable job; do not create ad hoc deletion SQL or delete the Auth user first.
6. Confirm the job reaches `completed`, the Auth user is gone, private objects and Mux playback are unavailable, and no owner rows remain.

Run the end-to-end drill in staging before enabling accounts. Include an interrupted run after each provider step and verify the retry finishes without leaking media or losing the audit record.
