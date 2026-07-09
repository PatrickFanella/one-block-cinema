#!/usr/bin/env python3
"""Static safety checks for the credential-free Supabase migration."""

from pathlib import Path
import re
import sys

MIGRATIONS = Path("supabase/migrations")
EXPECTED_TABLES = {
    "profiles",
    "user_safety",
    "devices",
    "notification_preferences",
    "projects",
    "project_shots",
    "media_assets",
    "sync_operations",
    "publications",
    "challenges",
    "challenge_submissions",
    "comments",
    "blocks",
    "reports",
    "moderation_jobs",
    "moderation_actions",
    "critique_requests",
    "critique_results",
    "feature_flags",
    "analytics_events",
}


def fail(message: str) -> None:
    print(f"migration check failed: {message}", file=sys.stderr)
    raise SystemExit(1)


files = sorted(MIGRATIONS.glob("*.sql"))
if not files:
    fail("no SQL migrations found")
if not Path("supabase/tests/rls.sql").is_file():
    fail("supabase/tests/rls.sql is missing")

sql = "\n".join(path.read_text() for path in files)
created = set(re.findall(r"create\s+table\s+public\.([a-z_]+)", sql, flags=re.IGNORECASE))
missing = EXPECTED_TABLES - created
if missing:
    fail(f"missing required tables: {', '.join(sorted(missing))}")

for table in sorted(EXPECTED_TABLES):
    if not re.search(
        rf"alter\s+table\s+public\.{table}\s+enable\s+row\s+level\s+security",
        sql,
        flags=re.IGNORECASE,
    ):
        fail(f"RLS is not enabled for public.{table}")
    if not re.search(
        rf"create\s+policy\s+[a-z0-9_]+\s+on\s+public\.{table}",
        sql,
        flags=re.IGNORECASE,
    ):
        fail(f"public.{table} has no policy")

required_fragments = (
    "private-drafts",
    "moderation-evidence",
    "is_blocked_with",
    "idempotency_key",
    "moderation_status = 'approved'",
    "teen_has_no_external_url",
)
for fragment in required_fragments:
    if fragment not in sql:
        fail(f"required safety contract is missing: {fragment}")

if not re.search(r"^begin;", sql, flags=re.IGNORECASE | re.MULTILINE):
    fail("migration must begin transactionally")
if not re.search(r"^commit;", sql, flags=re.IGNORECASE | re.MULTILINE):
    fail("migration must commit transactionally")

print(f"migration check passed: {len(files)} migration(s), {len(EXPECTED_TABLES)} RLS tables")
