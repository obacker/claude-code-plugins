#!/usr/bin/env python3
"""
Shared path predicates for ADLC-Solo PreToolUse guards.

Single source of truth for the path predicates, so guard-test-lock.py and
guard-migrations.py cannot drift apart on what counts as a test file, an
.sdlc/ file, or a project-relative path. Every consumer imports from here
with a try/except fallback; a hook must never hard-fail on an import error.

Nothing here raises. Predicates answer conservatively (allow) on bad input.
"""

import os

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


def flag_active(flag_name):
    """True if the named opt-in flag file exists under .sdlc/."""
    try:
        return os.path.exists(os.path.join(".sdlc", flag_name))
    except Exception:
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
