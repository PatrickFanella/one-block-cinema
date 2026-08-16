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

`MediaRenderIntegrationTests` generates short landscape and portrait H.264 sources plus project audio at runtime. It renders the shared production composition, inspects the resulting 1080p MP4 duration/video/audio tracks, and verifies corrupt media is rejected with an actionable app error. No private or committed binary fixtures are required.

Preview and export use the custom Core Image `CinemaVideoCompositor`; simulator integration tests cover title/intertitle pixels, silent-film treatment, crossfades, HDR-to-SDR Rec.709 normalization, and variable-frame-rate input without the former Core Animation postprocessor path.

## Backend testing

```bash
pnpm install --frozen-lockfile
pnpm check
python3 scripts/check_migrations.py
```

The static migration gate does not replace disposable-project RLS integration tests. Those remain required before any staging or production activation.

## Physical iPhone testing

Apple allows personal on-device testing without a paid Developer Program membership. Sign in to Xcode with a normal Apple Account; Xcode labels the resulting free signing identity as a **Personal Team**.

1. Open `ios/OneBlockCinema.xcodeproj` in Xcode.
2. Open **Xcode > Settings > Accounts**, add the Apple Account, and accept any requested developer agreement.
3. Select the `OneBlockCinema` app target.
4. In **Signing & Capabilities**, select the account's Personal Team and keep automatic signing enabled.
5. If Xcode reports that the bundle identifier is unavailable, change it locally to a unique reverse-domain identifier.
6. Connect and trust the iPhone, select it as the run destination, and press Run.

The project intentionally has no committed development team, so Personal Team details remain local. Apple's free workflow is for personal testing, supports a limited number of devices/App IDs, and requires periodic reprovisioning (currently every seven days). It cannot upload to TestFlight or the App Store. See Apple's [membership comparison](https://developer.apple.com/support/compare-memberships/) and [device-running guide](https://developer.apple.com/documentation/Xcode/running-your-app-on-simulated-or-physical-devices).

Use `make ios-device-qa` with local `OBC_DEVELOPMENT_TEAM` and `OBC_DEVICE_ID` values to build, install, and launch the DEBUG-only fault panel. Follow [DEVICE_QUALIFICATION.md](DEVICE_QUALIFICATION.md); never commit the local identifiers or captured media.

## Unsigned release archive

No Apple account is needed to validate Release packaging locally:

```bash
make archive-check
```

This creates `build/OneBlockCinema.xcarchive` without signing, then verifies the archived privacy manifest, production environment, disabled cloud features, and encryption declaration. Signing and distribution remain separate paid-account gates.

## Test priorities

1. `FilmSessionViewModel` session lifecycle.
2. `PromptGenerator` prompt count/content per template/theme.
3. `SessionStorage` save/load/delete behavior.
4. `VideoExportService` export behavior with fixture clips on macOS.
5. UI smoke tests for creation flow.

## Open Pilot test commands

Use the narrowest deterministic command in each issue. For docs/setup tasks, `make verify` is acceptable.
