# Deployment Runbook

## Environment boundary

Development, staging, and production use separate Supabase projects, databases, storage buckets, Mux environments, Fly apps, APNs credentials, and App Store configurations. Never reuse production service-role or media credentials outside production.

Committed defaults keep `FEATURE_COMMUNITY=false` and `FEATURE_AI_COACH=false`. A code deploy must not silently enable either feature.

The iOS target uses `OBC_APP_ENV=development` for Debug and `OBC_APP_ENV=production` for Release. A reviewed staging archive may override `OBC_APP_ENV=staging`. Connected builds inject only public client configuration through generated Info.plist keys:

- `INFOPLIST_KEY_OBCAPIBaseURL`
- `INFOPLIST_KEY_OBCSupabaseURL`
- `OBC_FEATURE_COMMUNITY`
- `OBC_FEATURE_AI_COACH`

Production endpoints must use HTTPS. Community remains inactive unless both public endpoints exist and its flag is explicitly enabled; AI remains inactive unless the API endpoint exists and its separate flag is enabled. These client flags do not replace server flags, consent, age, moderation, or rollout gates.

## Secret ownership

The following are server/release-runner secrets and must never enter the iOS bundle or git:

- `DATABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `MUX_TOKEN_ID`, `MUX_TOKEN_SECRET`, `MUX_WEBHOOK_SECRET`
- SMTP credentials
- App Store Connect API credentials and signing material
- future AI provider credentials

The moderation console receives only the Supabase URL and anon key. Admin authorization comes from signed `app_metadata`, not user-editable metadata.

## Promotion

1. Merge only after portable CI, executed simulator tests, and archive validation pass.
2. Apply migrations to a disposable database and run RLS integration tests.
3. Back up staging, apply migrations, and run API/community deletion and block tests.
4. Deploy `web` and `worker` as separate Fly process groups; expose only `web`.
5. Verify `/healthz`, queue processing, webhook replay protection, and scrubbed telemetry.
6. Promote the same reviewed artifact to production through the dedicated release runner.
7. Enable feature rollout separately, beginning with staff.

Before release, validate the built archive contains `PrivacyInfo.xcprivacy`, reconcile the manifest and App Store privacy answers with every enabled dependency, replace the placeholders in `docs/legal/`, and obtain owner/counsel approval.

Production deployment from an unreviewed pull request is prohibited.
