# Physical-Device Qualification

This checklist qualifies the local testing-production build on one iPhone 16 Plus running iOS 26.6. It does not qualify TestFlight, App Store distribution, external services, AI, 4K, HDR export, or older supported devices.

## Install the local DEBUG build

Connect and unlock the iPhone, trust the Mac, enable Developer Mode, and select a free Personal Team in Xcode once. Keep the team and device identifiers local:

```bash
OBC_DEVELOPMENT_TEAM="<personal-team-id>" \
OBC_DEVICE_ID="<local-device-id>" \
make ios-device-qa
```

The target builds with automatic signing and `-allowProvisioningUpdates`, installs through `devicectl`, and launches with `OBCDeviceQAEnabled`. It does not write either identifier to the repository.

## Qualification checklist

Record each item as Pass, Fail, or Blocked. Do not record device identifiers, media, filenames, account details, or other personal data.

### Permissions and camera

- [ ] Deny camera permission; confirm library import and the Settings recovery action remain available.
- [ ] Restore camera permission and confirm capture recovers without reinstalling.
- [ ] Deny microphone permission; confirm silent recording remains available and recovery works after permission is restored.
- [ ] Record with rear and front cameras.
- [ ] Verify rear-camera torch, zoom, tap focus, and tap exposure.
- [ ] Record in portrait and landscape orientation and inspect the saved orientation.
- [ ] Record with microphone enabled and disabled.
- [ ] Exercise retake and use-recording flows.

### Lifecycle and injected device conditions

- [ ] Background and foreground the app during camera preview and recording; confirm the camera suspends and recovers.
- [ ] Begin and end an injected camera interruption; confirm the reason and recovery state are visible.
- [ ] Inject a media-services reset; confirm automatic recovery.
- [ ] Enable low capture storage; confirm new recording is blocked with an actionable message.
- [ ] Enable serious thermal state; confirm a warning appears and the torch turns off without cancelling current work.
- [ ] Enable critical thermal state; confirm new work is blocked and active recording stops safely.
- [ ] Confirm a partial recording is offered only when it is readable and has positive duration.

### Preview and export

- [ ] Preview and export a title overlay; inspect the dark title band and bright text.
- [ ] Preview and export an intertitle card; inspect its background and text.
- [ ] Compare standard and silent-film exports; confirm the silent look is warmer and desaturated.
- [ ] Import an HLG/Main10 HDR clip; confirm SDR Rec.709 preview/export without clipped or invalid frames.
- [ ] Import a true variable-frame-rate clip; confirm smooth fixed-30-fps output and correct duration.
- [ ] Confirm mixed portrait/landscape sources crop correctly at the template aspect ratio.
- [ ] Confirm voiceover/ambient/source audio and microphone-disabled clips have the expected audio presence.
- [ ] Cancel export; confirm the draft and edit decisions are unchanged and no retry checkpoint appears.
- [ ] Inject low export storage; confirm export is blocked and incomplete output is removed.
- [ ] Inject critical thermal state during export; confirm cancellation, an interrupted checkpoint, and retry guidance.
- [ ] Expire export background time; confirm cancellation, relaunch recovery, and a successful retry replacing the checkpoint.
- [ ] Share a completed export through the system share sheet.

## Result record

| Field | Value |
| --- | --- |
| Date | 2026-07-10 |
| App commit | `61e745a` |
| Device class | iPhone 16 Plus |
| OS | iOS 26.6 |
| Result | Blocked before installation |
| Failed or blocked checks | The qualification iPhone was reported unavailable by CoreDevice. |
| Notes | Reconnect and unlock the phone, confirm trust and Developer Mode, then rerun the local install command. No device identifier was recorded. |

Older-device coverage remains a later public-release gate.
