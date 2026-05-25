# Open Pilot Readiness

Open Pilot can safely work in this repository when issues are specific, scoped, and verifiable.

## Required labels

Open Pilot only runs after both labels are present:

- `ready-for-agent`
- `agent:queued`

The issue template adds `ready-for-agent`. A human should add `agent:queued` only after reviewing the issue body.

## Issue requirements

Every agent-ready issue should include:

- Goal
- Context
- Acceptance Criteria
- Test Command
- Out of Scope
- Queue Checklist

## Test command guidance

Prefer the narrowest deterministic command that proves the requested change.

Examples:

```bash
make verify
xcodebuild test -project ios/OneBlockCinema.xcodeproj -scheme OneBlockCinema -destination 'platform=iOS Simulator,name=iPhone 16'
```

## PR review and merge

Open Pilot PR review expects the PR verification command to pass. If the deployed Open Pilot instance publishes commit statuses, merge gates should require the Open Pilot-owned status context before merging.
