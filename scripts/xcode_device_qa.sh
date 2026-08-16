#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/ios/OneBlockCinema.xcodeproj"
DERIVED_DATA="$ROOT/build/device-qa-derived"
APP="$DERIVED_DATA/Build/Products/Debug-iphoneos/OneBlockCinema.app"

: "${OBC_DEVELOPMENT_TEAM:?Set OBC_DEVELOPMENT_TEAM to your local Xcode Personal Team ID.}"
: "${OBC_DEVICE_ID:?Set OBC_DEVICE_ID to the local identifier from xcrun devicectl list devices.}"

if [[ ! "$OBC_DEVELOPMENT_TEAM" =~ ^[A-Za-z0-9]+$ ]]; then
    echo "OBC_DEVELOPMENT_TEAM must contain only letters and numbers." >&2
    exit 2
fi
if [[ "$OBC_DEVICE_ID" == *$'\n'* || "$OBC_DEVICE_ID" == *$'\r'* ]]; then
    echo "OBC_DEVICE_ID must be a single local device identifier." >&2
    exit 2
fi

xcodebuild build \
    -project "$PROJECT" \
    -scheme OneBlockCinema \
    -configuration Debug \
    -destination "id=$OBC_DEVICE_ID" \
    -derivedDataPath "$DERIVED_DATA" \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="$OBC_DEVELOPMENT_TEAM" \
    CODE_SIGN_STYLE=Automatic

if [[ ! -d "$APP" ]]; then
    echo "Signed device app was not produced at the expected Derived Data path." >&2
    exit 1
fi

xcrun devicectl device install app --device "$OBC_DEVICE_ID" "$APP"
xcrun devicectl device process launch \
    --device "$OBC_DEVICE_ID" \
    --terminate-existing \
    app.rork.uo0olvd981twnnwu0hz72 \
    -- OBCDeviceQAEnabled

echo "One-Block Cinema launched with the local DEBUG Device QA panel enabled."
