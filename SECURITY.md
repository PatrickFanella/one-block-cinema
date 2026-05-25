# Security Policy

## Supported scope

This repository is public and early-stage. Security work currently focuses on safe defaults, secret hygiene, user media privacy, community moderation boundaries, and clear automation scope.

## Reporting a vulnerability

Do not publish sensitive vulnerabilities in public issues.

Report privately to the repository owner or organization maintainer through the preferred private channel for the project. If no project-specific channel exists, contact the maintainer account for the Gitea organization.

Include:

- affected repository and commit
- impact summary
- reproduction steps
- affected configuration or deployment path
- suggested mitigation, if known

## Secret handling

Never commit:

- `.env` or `.env.*` files, except `.env.example`
- API tokens or OAuth secrets
- AI provider keys
- SSH keys or deploy keys
- database dumps containing real data
- private certificates or signing keys
- Apple signing/provisioning material
- webhook secrets

Use placeholders in docs and examples. Report only secret key names and presence, never secret values.

## Product privacy guardrails

One-Block Cinema handles user-created videos, drafts, profiles, comments, and challenge activity. Before launch, implementation must provide:

- private-until-publish defaults
- delete project/draft/comment/account controls
- export/share with user confirmation
- offline drafts that do not upload until sync/publish intent is clear
- no raw private media metadata in analytics events

## Open Pilot safety

Open Pilot tasks should include a deterministic `Test Command` and clear scope limits. Do not queue tasks that require secret access, production credentials, destructive data changes, or ambiguous deployment actions.

For risky work, require human review before adding `agent:queued`.
