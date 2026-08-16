#!/usr/bin/env python3
"""Validate the bundled production film-template catalog."""

from __future__ import annotations

import json
from pathlib import Path


RESOURCE_DIR = Path("ios/OneBlockCinema/Resources")
CATALOG_PATH = RESOURCE_DIR / "FilmTemplates.json"
SCHEMA_PATH = RESOURCE_DIR / "FilmTemplateV1.schema.json"
EXPECTED_TEMPLATE_IDS = {
    "first-block-story",
    "noir-shadow-mystery",
    "small-romance",
    "observational-portrait",
    "everyday-horror",
    "dream-walk",
    "silent-object-story",
    "voiceover-diary",
    "one-minute-how-to",
    "before-and-after-transformation",
}
REQUIRED_TOP_LEVEL_FIELDS = {
    "schemaVersion",
    "id",
    "title",
    "subtitle",
    "outcome",
    "theme",
    "difficulty",
    "durationTargetSeconds",
    "aspectRatio",
    "tags",
    "shotPrompts",
    "guidance",
    "assembly",
}
REQUIRED_DURATION_FIELDS = {"min", "ideal", "max"}
REQUIRED_SHOT_FIELDS = {
    "id",
    "title",
    "structureRole",
    "direction",
    "hint",
    "icon",
    "targetSeconds",
}
REQUIRED_GUIDANCE_FIELDS = {"structure", "capture", "assembly", "export"}
REQUIRED_ASSEMBLY_FIELDS = {"pacingStyle", "editStyle", "useAmbientSoundtrack"}
VALID_ASPECT_RATIOS = {"9:16", "1:1", "16:9", "4:5"}
VALID_THEMES = {"noir", "romance", "documentary", "horror", "dream"}
VALID_PACING_STYLES = {"quick_cuts", "slow_cinema", "rhythmic"}
VALID_EDIT_STYLES = {"standard", "silent_film", "voiceover_diary"}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)


def validate_template(template: dict[str, object], index: int) -> None:
    location = f"{CATALOG_PATH}: templates[{index}]"
    missing = REQUIRED_TOP_LEVEL_FIELDS - template.keys()
    require(not missing, f"{location}: missing fields: {', '.join(sorted(missing))}")
    require(template["schemaVersion"] == 1, f"{location}: schemaVersion must be 1")
    require(template["theme"] in VALID_THEMES, f"{location}: unsupported theme")
    require(template["aspectRatio"] in VALID_ASPECT_RATIOS, f"{location}: unsupported aspect ratio")

    duration = template["durationTargetSeconds"]
    require(isinstance(duration, dict), f"{location}: durationTargetSeconds must be an object")
    missing_duration = REQUIRED_DURATION_FIELDS - duration.keys()
    require(not missing_duration, f"{location}: missing duration fields: {', '.join(sorted(missing_duration))}")
    require(60 <= duration["min"] <= duration["ideal"] <= duration["max"] <= 180, f"{location}: duration target must stay within 60-180 seconds")

    prompts = template["shotPrompts"]
    require(isinstance(prompts, list) and 5 <= len(prompts) <= 9, f"{location}: shotPrompts must contain 5-9 entries")
    prompt_ids: set[str] = set()
    for prompt_index, prompt in enumerate(prompts):
        require(isinstance(prompt, dict), f"{location}: shotPrompts[{prompt_index}] must be an object")
        missing_prompt_fields = REQUIRED_SHOT_FIELDS - prompt.keys()
        require(not missing_prompt_fields, f"{location}: shotPrompts[{prompt_index}] missing fields: {', '.join(sorted(missing_prompt_fields))}")
        require(prompt["index"] == prompt_index, f"{location}: shotPrompts[{prompt_index}].index must equal its array position")
        require(prompt["targetSeconds"] > 0, f"{location}: shotPrompts[{prompt_index}].targetSeconds must be positive")
        require(prompt["structureRole"], f"{location}: shotPrompts[{prompt_index}].structureRole must teach structure")
        require(prompt["icon"], f"{location}: shotPrompts[{prompt_index}].icon must be present")
        require(prompt["id"] not in prompt_ids, f"{location}: duplicate shot prompt id {prompt['id']}")
        prompt_ids.add(prompt["id"])

    total_prompt_seconds = sum(prompt["targetSeconds"] for prompt in prompts)
    require(duration["min"] <= total_prompt_seconds <= duration["max"], f"{location}: prompt targets must sum within duration range")

    guidance = template["guidance"]
    require(isinstance(guidance, dict), f"{location}: guidance must be an object")
    missing_guidance = REQUIRED_GUIDANCE_FIELDS - guidance.keys()
    require(not missing_guidance, f"{location}: missing guidance fields: {', '.join(sorted(missing_guidance))}")

    assembly = template["assembly"]
    require(isinstance(assembly, dict), f"{location}: assembly must be an object")
    missing_assembly = REQUIRED_ASSEMBLY_FIELDS - assembly.keys()
    require(not missing_assembly, f"{location}: missing assembly fields: {', '.join(sorted(missing_assembly))}")
    require(assembly["pacingStyle"] in VALID_PACING_STYLES, f"{location}: unsupported pacingStyle")
    require(assembly["editStyle"] in VALID_EDIT_STYLES, f"{location}: unsupported editStyle")
    require(isinstance(assembly["useAmbientSoundtrack"], bool), f"{location}: useAmbientSoundtrack must be boolean")


def main() -> None:
    require(SCHEMA_PATH.is_file(), f"{SCHEMA_PATH}: schema file is missing")
    require(CATALOG_PATH.is_file(), f"{CATALOG_PATH}: catalog file is missing")
    schema = json.loads(SCHEMA_PATH.read_text())
    require(schema.get("$schema") == "https://json-schema.org/draft/2020-12/schema", f"{SCHEMA_PATH}: expected JSON Schema 2020-12")

    templates = json.loads(CATALOG_PATH.read_text())
    require(isinstance(templates, list), f"{CATALOG_PATH}: catalog must be an array")
    require(len(templates) == 10, f"{CATALOG_PATH}: catalog must contain exactly 10 templates")
    for index, template in enumerate(templates):
        require(isinstance(template, dict), f"{CATALOG_PATH}: templates[{index}] must be an object")
        validate_template(template, index)

    template_ids = [template["id"] for template in templates]
    require(len(template_ids) == len(set(template_ids)), f"{CATALOG_PATH}: template ids must be unique")
    require(set(template_ids) == EXPECTED_TEMPLATE_IDS, f"{CATALOG_PATH}: launch template ids do not match the production catalog")


if __name__ == "__main__":
    main()
