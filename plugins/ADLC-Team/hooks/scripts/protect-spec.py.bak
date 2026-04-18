#!/usr/bin/env python3
"""PreToolUse hook: block edits to approved spec files.

Intercepts Edit and Write tool calls (matched by hooks.json matcher).
If the target is a *-spec.md file inside .sdlc/specs/ and the corresponding
feature-registry.json has spec_approved_at set, the edit is denied.

Exit codes:
  0 — output JSON with permissionDecision
  2 — blocking error (stderr as message)
"""

import json
import sys
from pathlib import Path


def find_registry_for_spec(spec_path: str) -> str | None:
    """Find the feature-registry.json that governs this spec file."""
    spec_dir = Path(spec_path).parent
    candidates = [
        spec_dir / f"{Path(spec_path).stem.replace('-spec', '')}-registry.json",
        spec_dir / "feature-registry.json",
    ]
    for candidate in candidates:
        if candidate.exists():
            return str(candidate)
    return None


def is_spec_approved(registry_path: str) -> bool:
    """Check if spec_approved_at is set in the registry."""
    try:
        with open(registry_path) as f:
            data = json.load(f)
        return bool(data.get("spec_approved_at"))
    except (json.JSONDecodeError, OSError):
        return False


def is_spec_file(path: str) -> bool:
    """Check if this is a spec file we should protect."""
    p = Path(path)
    return p.name.endswith("-spec.md") and ".sdlc" in str(p)


def main():
    raw = sys.stdin.read()
    try:
        event = json.loads(raw)
    except json.JSONDecodeError:
        sys.exit(0)

    # Extract file path from tool input
    tool_input = event.get("tool_input", {})
    file_path = tool_input.get("file_path", "") or tool_input.get("path", "")

    if not file_path or not is_spec_file(file_path):
        # Not a spec file — allow
        result = {"hookSpecificOutput": {"permissionDecision": "allow"}}
        print(json.dumps(result))
        sys.exit(0)

    registry = find_registry_for_spec(file_path)
    if not registry or not is_spec_approved(registry):
        # Not tracked or not approved yet — allow
        result = {"hookSpecificOutput": {"permissionDecision": "allow"}}
        print(json.dumps(result))
        sys.exit(0)

    # Spec is approved — deny the edit
    reason = (
        f"Spec '{Path(file_path).name}' is approved and immutable. "
        "ACs cannot be modified after approval. "
        "To change requirements, create a new spec or request re-approval."
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
