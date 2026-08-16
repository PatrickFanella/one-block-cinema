# 0003 Camera and import parity

## Status

Accepted

## Context

The reliable import-first vertical slice from ADR 0002 is complete. The production roadmap now requires a full iPhone filmmaking toolkit without weakening offline creation or making camera permission a prerequisite.

## Decision

Add native AVFoundation movie capture while retaining Photos-library import as an equal option for every shot prompt.

The camera uses a 1080p session preset and provides front/rear switching, tap focus/exposure, torch, bounded zoom, automatic stabilization, contextual prompt/aspect guides, microphone control, a 180-second recording cap, retake review, and Settings recovery. Captures remain temporary until the user selects **Use Clip**, after which `MediaStore` creates the durable project-owned copy.

## Consequences

- Denied or unavailable camera hardware never blocks library import.
- Camera and microphone consent remain contextual and separate from accounts, sync, community, analytics, notifications, and AI.
- Simulator compilation is insufficient; representative physical-device tests remain required for focus, stabilization, rotation, interruption, audio, and thermal/storage behavior.
- ADR 0002 remains the history of the alpha sequencing decision but no longer defines the production feature set.
