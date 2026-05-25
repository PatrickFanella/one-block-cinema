# Conventions

## Scope

- Keep changes small and issue-scoped.
- Preserve Open Pilot templates and verification commands.
- Update docs when product or architecture decisions change.
- Do not commit secrets, signing material, generated caches, local data, or private media.

## Product behavior

- Prefer offline-capable flows.
- Keep projects/drafts private until explicit publish/share action.
- Do not let community/sync block local creation.
- Keep AI critique out of MVP unless a later issue changes scope.

## Swift/iOS

- Keep app source under `ios/`.
- Prefer clear SwiftUI view-model boundaries over view-local business logic.
- Keep media/export code isolated behind services.
- Add tests when changing domain/state/service logic.

## Documentation

- Product decisions live under `docs/product/`.
- Codebase facts live under `docs/codebase/`.
- Future backend/API contracts live under `docs/technical/`.
- Architecture decisions live under `docs/adr/`.

## Evidence

- `AGENTS.md`
- `README.md`
- `.gitea/ISSUE_TEMPLATE/open-pilot-task.yaml`
- `Makefile`
