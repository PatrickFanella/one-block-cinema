#!/usr/bin/env python3
"""Validate credential-free Release settings and an optional unsigned archive."""

from argparse import ArgumentParser
from pathlib import Path
import plistlib
import re
import sys


ROOT = Path(__file__).resolve().parent.parent
PROJECT = ROOT / "ios/OneBlockCinema.xcodeproj/project.pbxproj"
INFO_PLIST = ROOT / "ios/OneBlockCinema/Info.plist"
PRIVACY_MANIFEST = ROOT / "ios/OneBlockCinema/PrivacyInfo.xcprivacy"


def fail(message: str) -> None:
    print(f"release configuration check failed: {message}", file=sys.stderr)
    raise SystemExit(1)


def unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] == '"':
        return value[1:-1]
    return value


def release_settings() -> dict[str, str]:
    project = PROJECT.read_text()
    blocks = re.findall(
        r"/\* Release \*/ = \{\s*isa = XCBuildConfiguration;\s*"
        r"buildSettings = \{(.*?)\n\s*\};\s*name = Release;\s*\};",
        project,
        flags=re.DOTALL,
    )
    for block in blocks:
        settings = {
            match.group(1): unquote(match.group(2))
            for match in re.finditer(r"^\s*([A-Z0-9_]+) = ([^;]*);\s*$", block, re.MULTILINE)
        }
        if settings.get("INFOPLIST_FILE") == "OneBlockCinema/Info.plist":
            return settings
    fail("could not find the OneBlockCinema app Release build configuration")


def validate_source() -> None:
    for path in (PROJECT, INFO_PLIST, PRIVACY_MANIFEST):
        if not path.is_file():
            fail(f"missing required release file: {path.relative_to(ROOT)}")

    with INFO_PLIST.open("rb") as handle:
        info = plistlib.load(handle)

    for key in (
        "NSCameraUsageDescription",
        "NSMicrophoneUsageDescription",
        "NSPhotoLibraryUsageDescription",
    ):
        if not isinstance(info.get(key), str) or not info[key].strip():
            fail(f"{key} must contain a user-facing explanation")
    if info.get("ITSAppUsesNonExemptEncryption") is not False:
        fail("ITSAppUsesNonExemptEncryption must be false for the current local-only build")

    settings = release_settings()
    expected = {
        "GENERATE_INFOPLIST_FILE": "NO",
        "OBC_APP_ENV": "production",
        "OBC_FEATURE_AI_COACH": "NO",
        "OBC_FEATURE_COMMUNITY": "NO",
        "OBC_API_BASE_URL": "",
        "OBC_SUPABASE_URL": "",
        "DEVELOPMENT_TEAM": "",
    }
    for key, value in expected.items():
        if settings.get(key) != value:
            fail(f"Release {key} must be {value!r}, found {settings.get(key)!r}")
    if not settings.get("PRODUCT_BUNDLE_IDENTIFIER"):
        fail("Release PRODUCT_BUNDLE_IDENTIFIER must not be empty")
    if settings.get("CODE_SIGN_STYLE") != "Automatic":
        fail("Release signing must remain Automatic for local Personal Team selection")


def validate_archive(archive: Path) -> None:
    applications = archive / "Products/Applications"
    apps = list(applications.glob("*.app"))
    if len(apps) != 1:
        fail(f"expected one archived app in {applications}, found {len(apps)}")
    app = apps[0]
    archived_manifest = app / "PrivacyInfo.xcprivacy"
    if not archived_manifest.is_file():
        fail("PrivacyInfo.xcprivacy is missing from the archived app")
    with (app / "Info.plist").open("rb") as handle:
        info = plistlib.load(handle)
    expected = {
        "OBCEnvironment": "production",
        "OBCFeatureAICoach": "NO",
        "OBCFeatureCommunity": "NO",
        "ITSAppUsesNonExemptEncryption": False,
    }
    for key, value in expected.items():
        if info.get(key) != value:
            fail(f"archived {key} must be {value!r}, found {info.get(key)!r}")


def main() -> None:
    parser = ArgumentParser()
    parser.add_argument("--archive", type=Path, help="validate a built .xcarchive as well as source settings")
    args = parser.parse_args()
    validate_source()
    if args.archive:
        validate_archive(args.archive.resolve())
    suffix = " and archive" if args.archive else ""
    print(f"release configuration{suffix} check passed")


if __name__ == "__main__":
    main()
