#!/usr/bin/env python3
"""
PostToolUse hook: runs compile/type checks after Edit/Write on source files.

Reads the type-check command from verification.yml (post_slice → "Type check")
so it works with any stack — Go, TypeScript, Python, Rust, etc.

Falls back to extension-based detection if verification.yml is not configured.

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

try:
    import yaml as yaml_lib
    HAS_YAML = True
except ImportError:
    HAS_YAML = False


SKIP_EXTENSIONS = {".md", ".json", ".yaml", ".yml", ".toml", ".cfg", ".ini", ".env"}

# Fallback: extension-based checks when verification.yml is not available
FALLBACK_CHECKS = {
    ".go": "go vet ./... 2>&1 | head -20",
    ".ts": "npx tsc --noEmit 2>&1 | head -20",
    ".tsx": "npx tsc --noEmit 2>&1 | head -20",
    ".py": "python3 -m py_compile {file} 2>&1",
    ".rs": "cargo check 2>&1 | head -20",
}


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


def read_typecheck_from_verification_yml():
    """Read the Type check command from verification.yml post_slice section."""
    for path in ["verification.yml", "verification.yaml"]:
        if not os.path.exists(path):
            continue
        try:
            if HAS_YAML:
                with open(path) as f:
                    data = yaml_lib.safe_load(f)
            else:
                # Minimal YAML parsing for the specific field we need
                with open(path) as f:
                    content = f.read()
                # Look for "Type check" entry and extract command
                import re
                match = re.search(
                    r'-\s*name:\s*["\']?Type check["\']?\s*\n\s*command:\s*["\']?(.+?)["\']?\s*$',
                    content, re.MULTILINE
                )
                if match:
                    cmd = match.group(1).strip().strip('"').strip("'")
                    # Skip template variables
                    if "{{" not in cmd:
                        return cmd
                return None

            if not data:
                continue
            post_slice = data.get("post_slice", [])
            for entry in post_slice:
                if isinstance(entry, dict) and "type check" in entry.get("name", "").lower():
                    cmd = entry.get("command", "")
                    # Skip unfilled template variables
                    if cmd and "{{" not in cmd:
                        return cmd
        except Exception:
            continue
    return None


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

    # Strategy 1: Read type-check command from verification.yml (stack-agnostic)
    typecheck_cmd = read_typecheck_from_verification_yml()
    if typecheck_cmd:
        warning = run_check(f"{typecheck_cmd} 2>&1 | head -20", "type check")
        if warning:
            print(warning)
        sys.exit(0)

    # Strategy 2: Fallback to extension-based detection
    if ext in FALLBACK_CHECKS:
        cmd = FALLBACK_CHECKS[ext].replace("{file}", file_path)
        label = f"compile check ({ext})"
        warning = run_check(cmd, label)
        if warning:
            print(warning)

    sys.exit(0)


if __name__ == "__main__":
    main()
