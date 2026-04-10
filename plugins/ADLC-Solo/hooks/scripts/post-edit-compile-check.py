#!/usr/bin/env python3
"""
PostToolUse hook: runs compile/type checks after Edit/Write on source files.

Checks:
  - .go files → runs `go vet ./...`
  - .ts/.tsx files → runs `npx tsc --noEmit`

Skips:
  - .md, .json, .yaml, .yml files
  - .sdlc/ directory files
  - Test/spec/mock/fixture files

Output:
  Prints warnings to stdout (visible to the agent).
  PostToolUse hooks cannot deny — they run after the tool completes.
  Exit 0 always.
"""

import json
import os
import subprocess
import sys


SKIP_EXTENSIONS = {".md", ".json", ".yaml", ".yml", ".toml", ".cfg", ".ini", ".env"}


def should_skip(file_path):
    """Check if file should be skipped for compile checking."""
    if not file_path:
        return True

    normalized = file_path.replace("\\", "/")

    # Skip .sdlc/ files
    if ".sdlc/" in normalized or normalized.startswith(".sdlc"):
        return True

    # Skip by extension
    _, ext = os.path.splitext(normalized)
    if ext.lower() in SKIP_EXTENSIONS:
        return True

    # Skip test/spec/mock/fixture files
    basename = os.path.basename(normalized).lower()
    if ("_test." in basename or ".test." in basename or
        "_spec." in basename or ".spec." in basename or
        basename.startswith("test_") or basename.startswith("spec_")):
        return True

    parts = normalized.lower().split("/")
    test_dirs = ("test", "tests", "spec", "specs", "mock", "mocks",
                 "fixture", "fixtures", "testdata", "testutil",
                 "__tests__", "__test__", "__mocks__")
    for part in parts:
        if part in test_dirs:
            return True

    return False


def run_check(command, label):
    """Run a compile check command and return output if it fails."""
    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=12,
            shell=True
        )
        if result.returncode != 0:
            output = (result.stdout + result.stderr).strip()
            # Limit output to first 20 lines to avoid flooding
            lines = output.split("\n")[:20]
            return f"⚠ {label} WARNING:\n" + "\n".join(lines)
    except subprocess.TimeoutExpired:
        return f"⚠ {label}: timed out (>12s)"
    except Exception:
        pass
    return None


def main():
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            sys.exit(0)
        hook_input = json.loads(raw)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    tool_input = hook_input.get("tool_input", {})
    file_path = tool_input.get("file_path", "")

    if should_skip(file_path):
        sys.exit(0)

    _, ext = os.path.splitext(file_path)
    ext = ext.lower()

    warning = None

    if ext == ".go":
        warning = run_check("go vet ./... 2>&1 | head -20", "go vet")
    elif ext in (".ts", ".tsx"):
        warning = run_check("npx tsc --noEmit 2>&1 | head -20", "tsc --noEmit")

    if warning:
        print(warning)

    sys.exit(0)


if __name__ == "__main__":
    main()
