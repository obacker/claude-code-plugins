#!/usr/bin/env python3
"""
PreToolUse hook: blocks production code edits on main branch without worktree isolation.

Only active when .sdlc/.enforce-worktree flag file exists in the project root.
Projects opt-in by creating this file (e.g., via adlc-init or manually).

Allows:
  - .sdlc/ files (orchestrator's domain)
  - Test/spec/mock/fixture files and directories (qa-tester writes these)
  - Markdown files (docs, CLAUDE.md, domain-context.md)
  - Edits inside a git worktree (dev-agent runs here)

Blocks:
  - Production source code edits on main/master branch

Exit codes:
  0 = allow the tool call
  2 = block the tool call (reason sent via stdout JSON)
"""

import json
import os
import subprocess
import sys


def is_enforcement_active():
    """Check if worktree enforcement is enabled via flag file."""
    return os.path.exists(".sdlc/.enforce-worktree")


def is_in_worktree():
    """Check if current directory is a git worktree (not the main working tree)."""
    try:
        git_dir = subprocess.run(
            ["git", "rev-parse", "--git-dir"],
            capture_output=True, text=True, timeout=5
        ).stdout.strip()

        # Worktrees have git-dir like /path/.git/worktrees/<name>
        return "worktrees/" in git_dir
    except Exception:
        return False


def is_on_protected_branch():
    """Check if on main or master branch."""
    try:
        branch = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True, text=True, timeout=5
        ).stdout.strip()
        return branch in ("main", "master")
    except Exception:
        return False


def is_allowed_file(file_path):
    """Check if file is exempt from worktree enforcement."""
    if not file_path:
        return True

    normalized = file_path.replace("\\", "/")

    # .sdlc/ — orchestrator's domain, always allowed
    if ".sdlc/" in normalized or normalized.startswith(".sdlc"):
        return True

    # Markdown files — docs, CLAUDE.md, domain-context.md, etc.
    if normalized.endswith(".md"):
        return True

    # Test/spec/mock/fixture files or directories
    parts = normalized.lower().split("/")
    test_indicators = ("test", "tests", "spec", "specs", "mock", "mocks",
                       "fixture", "fixtures", "testdata", "testutil",
                       "__tests__", "__test__", "__mocks__")
    for part in parts:
        # Directory name matches
        if part in test_indicators:
            return True
        # File name contains test/spec indicators
        if part == os.path.basename(normalized).lower():
            if ("_test." in part or ".test." in part or
                "_spec." in part or ".spec." in part or
                part.startswith("test_") or part.startswith("spec_")):
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
    if not is_enforcement_active():
        sys.exit(0)

    tool_input = hook_input.get("tool_input", {})
    file_path = tool_input.get("file_path", "")

    if not file_path:
        sys.exit(0)

    # Always allow exempt files
    if is_allowed_file(file_path):
        sys.exit(0)

    # Allow if running inside a worktree (dev-agent)
    if is_in_worktree():
        sys.exit(0)

    # Block production code edits on main/master
    if is_on_protected_branch():
        basename = os.path.basename(file_path)
        result = {
            "decision": "block",
            "reason": (
                f"BLOCKED: Editing production code ({basename}) directly on main branch. "
                "ADLC requires production code changes in an isolated worktree via dev-agent. "
                "Delegate this edit to a dev-agent with isolation: worktree. "
                "To disable enforcement: remove .sdlc/.enforce-worktree"
            )
        }
        print(json.dumps(result))
        sys.exit(2)

    # Not on protected branch — allow (feature branch work is fine)
    sys.exit(0)


if __name__ == "__main__":
    main()
