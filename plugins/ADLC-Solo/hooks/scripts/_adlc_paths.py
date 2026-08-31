#!/usr/bin/env python3
"""
Shared path predicates for ADLC-Solo PreToolUse guards.

Single source of truth for the exemption rules so the Edit/Write guard
(enforce-worktree.py) and the Bash guard (guard-bash-write.py) cannot drift
apart. Every consumer imports from here with a try/except fallback — a hook
must never hard-fail on an import error.

Nothing here raises. Predicates answer conservatively (allow) on bad input.
"""

import glob
import json
import os
import subprocess

# Directory names that mark a path as test/spec/mock/fixture territory.
TEST_DIR_INDICATORS = (
    "test", "tests", "spec", "specs", "mock", "mocks",
    "fixture", "fixtures", "testdata", "testutil",
    "__tests__", "__test__", "__mocks__",
)


def normalize(file_path):
    """Normalize separators. Returns '' for falsy input."""
    if not file_path:
        return ""
    return str(file_path).replace("\\", "/")


def to_project_relative(file_path, cwd=None):
    """
    Rewrite an absolute path into one relative to the project root, so path
    predicates (`db/migrations/...`, `.sdlc/...`) match. Claude Code sends
    absolute file_path values; a guard comparing those against configured
    relative directories would never match.

    Paths outside the project, and anything unresolvable, come back unchanged.
    """
    normalized = normalize(file_path)
    if not normalized:
        return normalized
    if not os.path.isabs(normalized):
        return os.path.normpath(normalized).replace("\\", "/")
    try:
        base = cwd or os.getcwd()
        relative = os.path.relpath(os.path.normpath(normalized), base)
        if relative.startswith(".."):
            return normalized
        return relative.replace("\\", "/")
    except Exception:
        return normalized


def is_sdlc_path(file_path):
    """True if the path lives under .sdlc/ (orchestrator's domain)."""
    normalized = normalize(file_path)
    if not normalized:
        return False
    return ".sdlc/" in normalized or normalized.startswith(".sdlc")


def is_test_path(file_path):
    """True if the path is a test/spec/mock/fixture file or lives in such a dir."""
    normalized = normalize(file_path)
    if not normalized:
        return False

    parts = normalized.lower().split("/")
    basename = os.path.basename(normalized).lower()

    # Any directory component matching a test indicator.
    for part in parts:
        if part in TEST_DIR_INDICATORS:
            return True

    # Filename patterns.
    if ("_test." in basename or ".test." in basename or
            "_spec." in basename or ".spec." in basename or
            basename.startswith("test_") or basename.startswith("spec_")):
        return True

    return False


def is_exempt_from_worktree(file_path):
    """
    Exemption rules for worktree enforcement.

    Exempt: .sdlc/ files, markdown, test/spec/mock/fixture paths.
    An empty path is exempt (nothing to enforce against).
    """
    normalized = normalize(file_path)
    if not normalized:
        return True

    if is_sdlc_path(normalized):
        return True

    if normalized.endswith(".md"):
        return True

    if is_test_path(normalized):
        return True

    return False


def is_in_worktree(cwd=None):
    """True if cwd is inside a git worktree (not the main working tree)."""
    try:
        git_dir = subprocess.run(
            ["git", "rev-parse", "--git-dir"],
            capture_output=True, text=True, timeout=5, cwd=cwd
        ).stdout.strip()
        return "worktrees/" in git_dir
    except Exception:
        return False


def flag_active(flag_name):
    """True if the named opt-in flag file exists under .sdlc/."""
    try:
        return os.path.exists(os.path.join(".sdlc", flag_name))
    except Exception:
        return False


def is_spec_file(file_path):
    """True if the target is a milestone spec (milestone-spec.md or *-spec.md)."""
    normalized = normalize(file_path)
    if not normalized:
        return False
    basename = os.path.basename(normalized)
    return basename == "milestone-spec.md" or basename.endswith("-spec.md")


def is_spec_approved_for_file(file_path):
    """
    True if the file sits under a milestone whose feature-registry.json has
    spec_approved_at set.
    """
    normalized = normalize(file_path)
    if not normalized:
        return False

    try:
        registries = glob.glob(".sdlc/milestones/*/feature-registry.json")
    except Exception:
        return False
    if not registries:
        return False

    try:
        target = os.path.abspath(normalized)
        target_dir = os.path.dirname(target)
    except Exception:
        return False

    for registry_path in registries:
        try:
            registry_dir = os.path.dirname(os.path.abspath(registry_path))
        except Exception:
            continue

        if target_dir == registry_dir or target.startswith(registry_dir + os.sep):
            try:
                with open(registry_path, "r") as f:
                    data = json.load(f)
                if data.get("spec_approved_at"):
                    return True
            except (json.JSONDecodeError, FileNotFoundError, OSError, ValueError):
                continue

    return False


def deny(reason):
    """Build the PreToolUse deny payload."""
    return {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": reason,
        }
    }
