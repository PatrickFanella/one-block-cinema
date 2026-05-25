# API Spec

Backend API is planned, not implemented.

## MVP backend responsibilities

- Auth: email OTP, Google, Apple.
- Profiles: user-editable profile.
- Sync: projects, drafts, and community activity.
- Publishing: private drafts become public only after explicit publish.
- Community: daily/weekly challenges, comments, peer feedback.
- Moderation: reports, automated filters, manual review queue.
- Safety: mixed content with age gating.

## Candidate resources

### Auth

- `POST /auth/otp/start`
- `POST /auth/otp/verify`
- `POST /auth/oauth/google`
- `POST /auth/oauth/apple`
- `POST /auth/logout`

### Profile

- `GET /me`
- `PATCH /me`

### Projects/drafts

- `GET /projects`
- `POST /projects`
- `GET /projects/{id}`
- `PATCH /projects/{id}`
- `DELETE /projects/{id}`
- `POST /projects/{id}/publish`

### Challenges

- `GET /challenges?cadence=daily|weekly`
- `GET /challenges/{id}`
- `POST /challenges/{id}/submissions`

### Comments/feedback

- `GET /films/{id}/comments`
- `POST /films/{id}/comments`
- `DELETE /comments/{id}`
- `POST /comments/{id}/report`

### Moderation

- `POST /films/{id}/report`
- `GET /moderation/queue`
- `POST /moderation/actions`

## Offline/sync notes

- Client must be able to create/edit/export local drafts offline.
- Sync should be resumable and conflict-aware.
- Private drafts must not become public through sync alone.

## Open decisions

1. Backend language/framework.
2. Database schema.
3. Auth provider strategy.
4. Media storage strategy.
5. Moderation provider/tooling.
