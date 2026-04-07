#!/usr/bin/env python3
"""
PreToolUse hook: blocks modifications to milestone-spec.md ACs after user approval.

Triggered on Edit and Write tool calls. Checks if the target file is a milestone
spec and if the spec has been approved (spec_approved_at set in feature-registry.json).

Output:
  JSON with hookSpecificOutput.permissionDecision = "allow" or "deny"
  Exit 0 always — decision is in the JSON output.
"""

import json
import os
import sys
import glob


def find_feature_registries():
    """Find all feature-registry.json files in .sdlc/milestones/"""
    pattern = ".sdlc/milestones/*/feature-registry.json"
    return glob.glob(pattern)


def is_spec_approved_for_file(file_path):
    """Check if any registry marks the spec containing this file as approved."""
    registries = find_feature_registries()
    if not registries:
        return False

    # Check if the file being edited is in a milestone directory
    file_dir = os.path.dirname(os.path.abspath(file_path))

    for registry_path in registries:
        registry_dir = os.path.dirname(os.path.abspath(registry_path))

        # Check if the edited file is in the same milestone directory
        if file_dir == registry_dir or os.path.abspath(file_path).startswith(registry_dir):
            try:
                with open(registry_path, "r") as f:
                    data = json.load(f)
                if data.get("spec_approved_at"):
                    return True
            except (json.JSONDecodeError, FileNotFoundError):
                continue

    return False


def is_spec_file(file_path):
    """Check if the target file is a milestone spec."""
    if not file_path:
        return False
    basename = os.path.basename(file_path)
    # Match milestone-spec.md or any file ending in -spec.md
    return basename == "milestone-spec.md" or basename.endswith("-spec.md")


def main():
    # Read hook input from stdin (JSON with tool_name, tool_input)
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            sys.exit(0)
        hook_input = json.loads(raw)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)  # Can't parse input, allow

    tool_input = hook_input.get("tool_input", {})

    # Get target file path from Edit or Write tool input
    file_path = tool_input.get("file_path", "")

    if not file_path:
        sys.exit(0)  # No file path, allow

    if not is_spec_file(file_path):
        sys.exit(0)  # Not a spec file, allow

    if not is_spec_approved_for_file(file_path):
        sys.exit(0)  # Spec not approved yet, allow edits

    # Spec IS approved — DENY the modification
    reason = (
        "Spec is approved and immutable. "
        "Acceptance criteria in milestone-spec.md cannot be modified after user approval. "
        "If the spec needs changes, the user must explicitly re-approve. "
        "Report this to the orchestrator — do not attempt to bypass."
    )
    result = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }
    print(json.dumps(result))
    sys.exit(0)


if __name__ == "__main__":
    main()
