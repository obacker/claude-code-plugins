#!/usr/bin/env python3
"""
PreToolUse hook (matcher: Edit|Write|Bash): locks existing tests during a bugfix.

Active only when .sdlc/.bugfix-active exists. The bugfix skill creates the flag
in Phase 0 and removes it on every exit path, including aborts.

Rule: while a bugfix is in flight, existing test files are read-only. Creating a
NEW test file is allowed — that is the required RED step.

Rationale: the failure mode this guards against is a bugfix that edits the
failing test until it passes instead of fixing the defect. A test that was
written before the bug was known is evidence; rewriting evidence mid-
investigation destroys the only signal that the fix actually worked.

FAIL OPEN: unparseable input or an unresolvable path allows the operation.
Exit 0 always.
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from _adlc_paths import (
        deny, flag_active, is_sdlc_path, is_test_path, to_project_relative,
    )
    from _adlc_bashparse import extract_write_targets
except Exception:
    sys.exit(0)


def offending_target(targets):
    """First target that is an existing test file, else None."""
    for target in targets:
        if not target:
            continue
        # .sdlc/ is the orchestrator's domain (bugfix reports live there).
        if is_sdlc_path(target):
            continue
        if not is_test_path(target):
            continue
        try:
            if not os.path.exists(target):
                continue  # New test file — allowed, this is the RED step.
        except Exception:
            continue
        return target
    return None


def main():
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            sys.exit(0)
        hook_input = json.loads(raw)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    if not flag_active(".bugfix-active"):
        sys.exit(0)

    tool_input = hook_input.get("tool_input", {})
    if not isinstance(tool_input, dict):
        sys.exit(0)

    targets = []
    file_path = tool_input.get("file_path", "")
    if file_path:
        targets.append(to_project_relative(file_path))

    command = tool_input.get("command", "")
    if command:
        try:
            targets.extend(extract_write_targets(command))
        except Exception:
            sys.exit(0)

    if not targets:
        sys.exit(0)

    offender = offending_target(targets)
    if offender:
        print(json.dumps(deny(
            f"Existing test file {os.path.basename(offender)} is locked during a bugfix. "
            "A bugfix must not modify the tests that define correct behavior — "
            "write a NEW failing test that reproduces the bug, then fix the code. "
            "If this test is genuinely wrong, say so and stop; that is a spec change, "
            "not a bugfix. To disable enforcement: remove .sdlc/.bugfix-active"
        )))
    sys.exit(0)


if __name__ == "__main__":
    main()
