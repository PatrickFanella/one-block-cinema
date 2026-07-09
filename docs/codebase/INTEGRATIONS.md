# Integrations

## Current app integrations

- Photos/library import through iOS media APIs.
- AVFoundation camera capture with front/rear cameras, focus/exposure, torch, zoom, stabilization, microphone control, and retake review.
- AVFoundation video export.
- Native share sheet/export handoff.
- GRDB SQLite persistence for draft metadata and relative app-support media paths, with legacy JSON/`UserDefaults` migration and recovery records.
- Fastify API contracts, pg-boss worker queues, Supabase schema/RLS, and an admin-role moderation console are implemented as inactive infrastructure foundations.

## Configured later with server-only credentials

- Email OTP auth.
- Google auth.
- Apple auth.
- Supabase sync for projects, drafts, profiles, comments, and challenge activity.
- Mux direct uploads, signed playback, and processing webhooks.
- Automated moderation and external account/media cleanup workers.
- Social share/export destinations through platform share sheet first.

## Post-MVP integrations
- AI critique provider wrapper.
- Advanced analytics, if privacy-safe.
- The admin console exists; operational SSO, hosting, and moderator drills remain future activation work.

## Guardrails

- `.env.example` may contain placeholder names only.
- Do not commit real OAuth, backend, AI, or Apple signing secrets.
- Private drafts should not auto-publish or auto-upload beyond explicit sync behavior.
