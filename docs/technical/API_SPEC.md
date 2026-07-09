# API Spec

The credential-free backend foundation lives in `backend/`; external integrations remain disabled until their server-only environment is configured. Native Supabase Auth handles email OTP, Apple, and Google. The Fastify service verifies Supabase access tokens and never accepts a service-role credential from a client.

## Runtime

- Fastify TypeScript web service and a separate pg-boss worker process.
- PostgreSQL/Supabase migration in `supabase/migrations/`.
- Zod owns request contracts; response bodies are explicit and freeform bodies have length limits.
- Fly process groups expose only `web`; `worker` has no public service.
- Community and AI feature flags default off in every committed environment.

## Authentication and idempotency

All `/v1` routes except `/v1/webhooks/mux` require `Authorization: Bearer <Supabase access token>`.

Every mutation except the signed Mux webhook requires:

```http
Idempotency-Key: 550e8400-e29b-41d4-a716-446655440000
```

The server stores `(owner_id, idempotency_key, operation, request_hash)` in `sync_operations`. Repeating an identical completed request returns its saved response. Reusing a key with a different body returns `409`.

## Routes

### Publishing and media

- `POST /v1/publications` — creates a private, unlisted, or challenge-public publication. Non-private content begins as `pending_review`.
- `POST /v1/upload-requests` — contract exists but returns `503` until Mux credentials and the direct-upload gateway are configured.
- `POST /v1/webhooks/mux` — requires a fresh HMAC `mux-signature`, queues the event, and rejects unsigned/replayed payloads.

### Challenges and feedback

- `GET /v1/challenges`
- `GET /v1/challenges/{id}/submissions`
- `POST /v1/comments`
- `DELETE /v1/comments/{id}`
- `POST /v1/reports`
- `POST /v1/blocks`
- `DELETE /v1/blocks`

Challenge discovery returns only active challenges and approved public submissions. Server queries remove either direction of a blocked relationship. Comments require an approved publication with comments enabled.

### Account and critique

- `DELETE /v1/account` — creates a durable deletion operation; external auth/storage revocation remains a release-blocking worker step.
- `POST /v1/critiques` — returns `503` while `FEATURE_AI_COACH=false`. No AI provider call is implemented or configured.

## Database safety

- Every public table has RLS.
- Projects, project shots, original media, devices, notification settings, sync operations, and critique data are owner-only.
- Only approved, public publications are discoverable through client RLS.
- Block-aware security-definer predicates enforce reciprocal hiding without exposing the block graph.
- `user_safety` is owner/admin only; teen profiles cannot store external links.
- Moderation jobs/actions and evidence storage are admin/moderator only based on immutable `app_metadata` roles.
- Private draft storage paths must begin with the authenticated owner UUID.

## Current activation gaps

- Configure separate development, staging, and production Supabase projects.
- Complete Mux direct-upload issuance and signed playback.
- Complete account deletion across Storage, Auth, Mux, and Sign in with Apple revocation.
- Exercise the SQL migration and RLS tests against disposable Supabase instances.
- Keep AI critique disabled until its separate consent, provider, safety, and evaluation gates are implemented.
