#!/usr/bin/env python3
"""PreToolUse hook: block production code edits outside a git worktree.

The orchestrator (main conversation) may only edit ADLC artifacts (.sdlc/,
CLAUDE.md, docs). Production/test code edits must happen inside a worktree
— meaning they must come from a spawned dev-agent or qa-agent.

This prevents the "lazy path" where the AI skips agent spawning and
edits code directly in the main conversation.

Allowed outside worktree:
  - .sdlc/**          (ADLC workflow artifacts)
  - CLAUDE.md          (project config)
  - *.md in repo root  (docs)
  - .claude/**         (Claude config)

Everything else → deny unless in a git worktree.
"""

import json
import os
import subprocess
import sys
from pathlib import Path


def is_in_worktree() -> bool:
    """Check if current working directory is a git worktree (not main repo)."""
    try:
        # git rev-parse --git-common-dir returns the shared .git dir
        # git rev-parse --git-dir returns the worktree-specific .git dir
        # If they differ, we're in a worktree
        common = subprocess.run(
            ["git", "rev-parse", "--git-common-dir"],
            capture_output=True, text=True, timeout=5
        ).stdout.strip()
        gitdir = subprocess.run(
            ["git", "rev-parse", "--git-dir"],
            capture_output=True, text=True, timeout=5
        ).stdout.strip()
        return common != gitdir
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return False


def is_adlc_artifact(file_path: str) -> bool:
    """Check if this file is an ADLC artifact (allowed to edit from main)."""
    p = Path(file_path)
    parts = p.parts

    # .sdlc/ directory — always allowed
    if ".sdlc" in parts:
        return True

    # .claude/ directory — always allowed
    if ".claude" in parts:
        return True

    # Root-level markdown files — allowed (CLAUDE.md, README.md, etc.)
    # Check: file is .md and parent is the repo root (no deep nesting)
    try:
        repo_root = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, timeout=5
        ).stdout.strip()
        if p.suffix == ".md" and str(p.parent) == repo_root:
            return True
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass

    # Config files at root — allowed
    root_configs = {
        "package.json", "tsconfig.json", "pyproject.toml",
        "go.mod", "go.sum", "Cargo.toml", "Cargo.lock",
        ".gitignore", ".env.example", "docker-compose.yml",
        "Dockerfile", "Makefile",
    }
    if p.name in root_configs:
        return True

    return False


def main():
    raw = sys.stdin.read()
    try:
        event = json.loads(raw)
    except json.JSONDecodeError:
        # Can't parse — allow (fail open)
        result = {"hookSpecificOutput": {"permissionDecision": "allow"}}
        print(json.dumps(result))
        sys.exit(0)

    tool_input = event.get("tool_input", {})
    file_path = tool_input.get("file_path", "") or tool_input.get("path", "")

    if not file_path:
        result = {"hookSpecificOutput": {"permissionDecision": "allow"}}
        print(json.dumps(result))
        sys.exit(0)

    # ADLC artifacts are always editable from main conversation
    if is_adlc_artifact(file_path):
        result = {"hookSpecificOutput": {"permissionDecision": "allow"}}
        print(json.dumps(result))
        sys.exit(0)

    # Production/test code — must be in a worktree
    if is_in_worktree():
        result = {"hookSpecificOutput": {"permissionDecision": "allow"}}
        print(json.dumps(result))
        sys.exit(0)

    # Not in worktree, editing production code → deny
    reason = (
        f"Cannot edit '{Path(file_path).name}' from main conversation. "
        "Production and test code must be edited inside a worktree. "
        "Spawn a dev-agent (isolation: worktree) or qa-agent (isolation: worktree) to make this change."
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
