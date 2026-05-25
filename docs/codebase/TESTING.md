# Testing

## Default verification

Run from repo root:

```bash
make verify
```

Current Linux baseline:

- checks required docs exist
- checks Open Pilot templates exist
- checks common secret filenames are not tracked
- skips Swift formatter/linter because none is configured yet
- skips Xcode tests because Linux runner cannot execute them

## Xcode testing

Future macOS runner command:

```bash
xcodebuild test -project ios/OneBlockCinema.xcodeproj -scheme OneBlockCinema -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Test priorities

1. `FilmSessionViewModel` session lifecycle.
2. `PromptGenerator` prompt count/content per template/theme.
3. `SessionStorage` save/load/delete behavior.
4. `VideoExportService` export behavior with fixture clips on macOS.
5. UI smoke tests for creation flow.

## Open Pilot test commands

Use the narrowest deterministic command in each issue. For docs/setup tasks, `make verify` is acceptable.
