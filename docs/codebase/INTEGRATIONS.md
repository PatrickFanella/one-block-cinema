# Integrations

## Current app integrations

- Photos/library import through iOS media APIs.
- AVFoundation video export.
- Native share sheet/export handoff.
- Local persistence through `UserDefaults`.

## Planned MVP integrations

- Email OTP auth.
- Google auth.
- Apple auth.
- Backend sync for projects, drafts, profiles, comments, and challenge activity.
- Community moderation/reporting service.
- Social share/export destinations through platform share sheet first.

## Post-MVP integrations

- Real in-app camera recording through iOS camera APIs.
- AI critique provider wrapper.
- Advanced analytics, if privacy-safe.
- Web/admin tooling for moderation.

## Guardrails

- `.env.example` may contain placeholder names only.
- Do not commit real OAuth, backend, AI, or Apple signing secrets.
- Private drafts should not auto-publish or auto-upload beyond explicit sync behavior.
