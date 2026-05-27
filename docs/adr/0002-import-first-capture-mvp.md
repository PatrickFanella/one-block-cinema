# 0002 Import-first capture for MVP

## Status

Accepted

## Context

The generated app shell includes camera-facing language, but the real camera path is not yet verified. A reliable first MVP slice needs users to attach clips to guided prompts without taking on camera permissions, recording reliability, device-specific QA, and fallback/error handling at the same time as template, draft, assembly, export, sync, and community scope.

## Decision

The MVP capture strategy is **import-first**. Users will add prompt clips from the iOS photo library and tag those imported clips to template prompts. Real in-app camera recording is not required for the MVP milestone.

## Consequences

- MVP implementation should prioritize library import, prompt-to-clip attachment, local draft persistence, assembly, preview, and export.
- Camera UI may exist only if clearly labeled as placeholder or disabled until a later camera-focused issue implements and verifies recording.
- In-app recording, cinematic viewfinder overlays, camera permission flows, recording error recovery, and device camera QA are out of scope for MVP.
- Follow-up implementation issues should target import-first flows before adding real camera capture.
