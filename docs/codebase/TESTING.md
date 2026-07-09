# Testing

## Default verification

Run from repo root:

```bash
make verify
```

Current Linux baseline:

- checks required docs exist
- validates the ten-template catalog and required RLS table/policy coverage
- typechecks the Fastify service, worker, and moderation console when pnpm is installed
- runs backend contract and webhook-signature tests
- checks Open Pilot templates exist
- checks common secret filenames are not tracked
- runs SwiftFormat/SwiftLint when installed (macOS CI requires both)
- skips Xcode tests because Linux runner cannot execute them

## Xcode testing

macOS simulator command:

```bash
xcodebuild test -project ios/OneBlockCinema.xcodeproj -scheme OneBlockCinema -destination 'platform=iOS Simulator,name=iPhone 17' CODE_SIGNING_ALLOWED=NO
```

Use `xcodebuild -showdestinations -project ios/OneBlockCinema.xcodeproj -scheme OneBlockCinema` if that simulator is not installed.

## Backend testing

```bash
pnpm install --frozen-lockfile
pnpm check
python3 scripts/check_migrations.py
```

The static migration gate does not replace disposable-project RLS integration tests. Those remain required before any staging or production activation.

## Physical iPhone testing

1. Open `ios/OneBlockCinema.xcodeproj` in Xcode.
2. Select the `OneBlockCinema` app target.
3. In Signing & Capabilities, select a development team for the app target.
4. Keep automatic signing enabled.
5. Select the connected iPhone as the run destination and press Run.

The project currently has no committed development team. Keep personal signing state local unless release automation needs a shared team configuration.

## Test priorities

1. `FilmSessionViewModel` session lifecycle.
2. `PromptGenerator` prompt count/content per template/theme.
3. `SessionStorage` save/load/delete behavior.
4. `VideoExportService` export behavior with fixture clips on macOS.
5. UI smoke tests for creation flow.

## Open Pilot test commands

Use the narrowest deterministic command in each issue. For docs/setup tasks, `make verify` is acceptable.
