# Agent Instructions

This repository follows the SUBCULT Open Pilot-ready template conventions, adapted for One-Block Cinema.

## Project

One-Block Cinema is an iPhone-first filmmaking coach for beginners and hobbyists with smartphones.

Core promise: “Turn a smartphone into a step-by-step filmmaking coach for structured 1–3 minute shorts.”

## Priorities

1. Keep issues small, scoped, and independently verifiable.
2. Preserve Open Pilot issue and PR templates.
3. Keep generated caches, secrets, local data, and signing material out of git.
4. Update docs when product, architecture, or verification conventions change.
5. Prefer offline-capable local-first app behavior; sync/community should enhance, not block, creation.

## Key docs

- `docs/product/PRD.md`
- `docs/product/MVP_SCOPE.md`
- `docs/product/ROADMAP.md`
- `docs/technical/API_SPEC.md`
- `docs/codebase/STACK.md`
- `docs/open-pilot.md`

## Verification

Run:

```bash
make verify
```

Use narrower commands only when an issue explicitly asks for a smaller check.

Current baseline is Linux-friendly and does not require Xcode. Add Xcode checks when macOS runner is available.

## Open Pilot

Open Pilot tasks must include:

- `ready-for-agent`
- deterministic `Test Command`
- specific acceptance criteria
- explicit out-of-scope notes

Do not add `agent:queued` until the issue is final and safe for automation.
