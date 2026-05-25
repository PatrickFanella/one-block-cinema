#!/usr/bin/env python3
"""Validate production-shaped product templates."""

from __future__ import annotations

import json
from pathlib import Path


TEMPLATE_DIR = Path("docs/product/templates")
REQUIRED_TOP_LEVEL_FIELDS = {
    "schemaVersion",
    "id",
    "title",
    "outcome",
    "durationTargetSeconds",
    "aspectRatio",
    "shotPrompts",
    "guidance",
}
REQUIRED_DURATION_FIELDS = {"min", "ideal", "max"}
REQUIRED_SHOT_FIELDS = {
    "id",
    "title",
    "structureRole",
    "direction",
    "hint",
    "targetSeconds",
}
REQUIRED_GUIDANCE_FIELDS = {"structure", "capture", "assembly", "export"}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def validate_template(path: Path) -> None:
    template = json.loads(path.read_text())

    missing = REQUIRED_TOP_LEVEL_FIELDS - template.keys()
    require(not missing, f"{path}: missing fields: {', '.join(sorted(missing))}")

    duration = template["durationTargetSeconds"]
    missing_duration = REQUIRED_DURATION_FIELDS - duration.keys()
    require(not missing_duration, f"{path}: missing duration fields: {', '.join(sorted(missing_duration))}")
    require(60 <= duration["min"] <= duration["ideal"] <= duration["max"] <= 180, f"{path}: duration target must stay within 60-180 seconds")

    prompts = template["shotPrompts"]
    require(isinstance(prompts, list) and bool(prompts), f"{path}: shotPrompts must be a non-empty array")
    for index, prompt in enumerate(prompts):
        missing_prompt_fields = REQUIRED_SHOT_FIELDS - prompt.keys()
        require(not missing_prompt_fields, f"{path}: shotPrompts[{index}] missing fields: {', '.join(sorted(missing_prompt_fields))}")
        require(prompt["targetSeconds"] > 0, f"{path}: shotPrompts[{index}].targetSeconds must be positive")
        require(prompt["structureRole"], f"{path}: shotPrompts[{index}].structureRole must teach structure")

    total_prompt_seconds = sum(prompt["targetSeconds"] for prompt in prompts)
    require(duration["min"] <= total_prompt_seconds <= duration["max"], f"{path}: prompt targets must sum within duration range")

    guidance = template["guidance"]
    missing_guidance = REQUIRED_GUIDANCE_FIELDS - guidance.keys()
    require(not missing_guidance, f"{path}: missing guidance fields: {', '.join(sorted(missing_guidance))}")


def main() -> None:
    template_paths = sorted(TEMPLATE_DIR.glob("*.json"))
    require(bool(template_paths), f"{TEMPLATE_DIR}: no template JSON files found")
    for path in template_paths:
        validate_template(path)


if __name__ == "__main__":
    main()
