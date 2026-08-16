#!/usr/bin/env bash
set -euo pipefail

project="ios/OneBlockCinema.xcodeproj"
scheme="OneBlockCinema"

if ! command -v xcodebuild >/dev/null 2>&1 || ! command -v xcrun >/dev/null 2>&1; then
  echo "xcodebuild and xcrun are required" >&2
  exit 1
fi

device_id="$(xcrun simctl list devices available 2>/dev/null | awk -F '[()]' '/iPhone/ && /Booted|Shutdown/ { print $2; exit }')"
if [[ -z "$device_id" ]]; then
  echo "No available iPhone simulator was found. Update Xcode/CoreSimulator and install an iOS simulator runtime." >&2
  exit 1
fi

xcodebuild test \
  -project "$project" \
  -scheme "$scheme" \
  -destination "platform=iOS Simulator,id=$device_id" \
  CODE_SIGNING_ALLOWED=NO
