# 0001 Local-first iOS MVP

## Status

Accepted

## Context

One-Block Cinema needs to help beginners create short films from a smartphone. The app must support offline editing/export, while later sync/community features enhance the experience.

## Decision

Build the MVP as an iPhone-first local-capable app. Keep creation, drafts, and export usable without backend availability. Add auth/sync/community as layers that do not block local creation.

## Consequences

- Draft/project data model must support local persistence and later sync.
- Community publishing must be explicit and private-until-publish.
- Backend design must account for offline conflict handling.
