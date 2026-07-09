# App Store privacy disclosure worksheet

## Current local-only build

- Tracking: No.
- Data linked to the user: None collected by the app operator.
- Data not linked to the user: None collected by the app operator.
- Camera/microphone/photo library: on-device feature access, not operator collection.
- Required-reason APIs: disk-space check (`E174.1`) and app-only UserDefaults (`CA92.1`).
- Privacy manifest: `ios/OneBlockCinema/PrivacyInfo.xcprivacy`.

This worksheet describes the committed configuration with external integrations and first-party analytics disabled. App Store Connect answers must be re-reviewed from the built archive and every enabled SDK/service before submission.

## Re-review before connected features

Accounts, sync, publishing, comments/reports, notifications, first-party analytics, Mux processing, and AI critique will change the disclosure. For each enabled data type, document purpose, user linkage, tracking status, retention, processor, deletion propagation, and whether collection is optional. Do not enable a feature flag until policy, consent, manifest, nutrition-label, and deletion behavior agree.
