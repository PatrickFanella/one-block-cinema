#!/usr/bin/env python3
from pathlib import Path
import plistlib


manifest_path = Path("ios/OneBlockCinema/PrivacyInfo.xcprivacy")
with manifest_path.open("rb") as handle:
    manifest = plistlib.load(handle)

assert manifest.get("NSPrivacyTracking") is False, "tracking must remain disabled"
assert manifest.get("NSPrivacyCollectedDataTypes") == [], (
    "the local-only build must not declare collected data; update this check when collection is activated"
)

accessed = {
    item["NSPrivacyAccessedAPIType"]: item["NSPrivacyAccessedAPITypeReasons"]
    for item in manifest.get("NSPrivacyAccessedAPITypes", [])
}
expected = {
    "NSPrivacyAccessedAPICategoryDiskSpace": ["E174.1"],
    "NSPrivacyAccessedAPICategoryUserDefaults": ["CA92.1"],
}
assert accessed == expected, f"unexpected required-reason declarations: {accessed!r}"
print("privacy manifest check passed: tracking off, no collection, 2 required-reason APIs")
