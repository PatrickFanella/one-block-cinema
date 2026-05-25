# Contributing

This repository uses SUBCULT Open Pilot-ready conventions.

## Development flow

1. Create or pick an issue before making non-trivial changes.
2. Create a branch from `main`.
3. Make the smallest change that satisfies the issue.
4. Run verification:

   ```bash
   make verify
   ```

5. Open a pull request using the PR template.
6. Link the issue with `Closes #N` when appropriate.

## Commit style

Prefer concise conventional-style subjects:

```text
feat: add project export
docs: update MVP scope
fix: preserve offline drafts
chore: refresh repo metadata
```

## Open Pilot issues

Use `.gitea/ISSUE_TEMPLATE/open-pilot-task.yaml` for tasks that Open Pilot should implement.

Open Pilot requires:

- `ready-for-agent`
- `agent:queued`
- a deterministic `Test Command`

The template adds `ready-for-agent`; add `agent:queued` only after the issue is complete and ready for automation.

## Verification commands

Use the narrowest deterministic command that proves the change.

Default full check:

```bash
make verify
```

Future Xcode example:

```bash
xcodebuild test -project ios/OneBlockCinema.xcodeproj -scheme OneBlockCinema -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Boundaries

- Do not commit secrets, signing keys, local databases, generated caches, or Apple signing/provisioning material.
- Do not add production deploy actions without an explicit issue and human approval.
- Do not add `agent:queued` to vague, broad, or secret-dependent issues.
