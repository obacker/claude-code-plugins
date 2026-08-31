#!/usr/bin/env python3
"""
PreToolUse hook (matcher: Edit|Write): blocks production code edits without
worktree isolation.

Only active when .sdlc/.enforce-worktree flag file exists in the project root.
Projects opt in by creating this file (e.g., via adlc-init or manually).

Allows:
  - .sdlc/ files (orchestrator's domain)
  - Test/spec/mock/fixture files and directories (QA agents write these)
  - Markdown files (docs, CLAUDE.md, domain-context.md)
  - Edits inside a git worktree (dev-agent runs here)

Blocks:
  - Production source code edits on ANY branch when not in a worktree

The exemption rules live in _adlc_paths.py so this hook and the Bash guard
(guard-bash-write.py) cannot drift apart. An inline fallback keeps the hook
working if that module is unavailable.

Output:
  JSON with hookSpecificOutput.permissionDecision = "deny", or exit silently
  to allow. Exit 0 always.
"""

import json
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from _adlc_paths import (
        deny, flag_active, is_exempt_from_worktree, is_in_worktree,
    )
except Exception:
    # --- Inline fallback: keep behavior identical if the module is missing ---
    def deny(reason):
        return {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": reason,
            }
        }

    def flag_active(flag_name):
        return os.path.exists(os.path.join(".sdlc", flag_name))

    def is_in_worktree(cwd=None):
        try:
            git_dir = subprocess.run(
                ["git", "rev-parse", "--git-dir"],
                capture_output=True, text=True, timeout=5, cwd=cwd
            ).stdout.strip()
            return "worktrees/" in git_dir
        except Exception:
            return False

    def is_exempt_from_worktree(file_path):
        if not file_path:
            return True
        normalized = file_path.replace("\\", "/")
        if ".sdlc/" in normalized or normalized.startswith(".sdlc"):
            return True
        if normalized.endswith(".md"):
            return True
        parts = normalized.lower().split("/")
        basename = os.path.basename(normalized).lower()
        test_indicators = ("test", "tests", "spec", "specs", "mock", "mocks",
                           "fixture", "fixtures", "testdata", "testutil",
                           "__tests__", "__test__", "__mocks__")
        for part in parts:
            if part in test_indicators:
                return True
        if ("_test." in basename or ".test." in basename or
                "_spec." in basename or ".spec." in basename or
                basename.startswith("test_") or basename.startswith("spec_")):
            return True
        return False


def main():
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            sys.exit(0)
        hook_input = json.loads(raw)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    # Enforcement must be explicitly enabled
    if not flag_active(".enforce-worktree"):
        sys.exit(0)

    tool_input = hook_input.get("tool_input", {})
    if not isinstance(tool_input, dict):
        sys.exit(0)
    file_path = tool_input.get("file_path", "")

    if not file_path:
        sys.exit(0)

    # Always allow exempt files
    if is_exempt_from_worktree(file_path):
        sys.exit(0)

    # Allow if running inside a worktree (dev-agent)
    if is_in_worktree():
        sys.exit(0)

    # Block production code edits on ANY branch when not in a worktree
    basename = os.path.basename(file_path)
    print(json.dumps(deny(
        f"Cannot edit production code ({basename}) directly. "
        "ADLC requires production code changes in an isolated worktree via dev-agent. "
        "Delegate this edit to a dev-agent with isolation: worktree. "
        "To disable enforcement: remove .sdlc/.enforce-worktree"
    )))
    sys.exit(0)


if __name__ == "__main__":
    main()
