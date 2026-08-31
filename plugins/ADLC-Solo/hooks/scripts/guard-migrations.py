#!/usr/bin/env python3
"""
PreToolUse hook (matcher: Edit|Write|Bash): paired-migration guard.

Active only when .sdlc/.enforce-migrations exists AND a `migrations:` block is
configured in verification.yml. Without both, the guard is inert.

Configuration (optional block, read from .sdlc/verification.yml first, then
verification.yml at the project root — adlc-init writes the latter):

    migrations:
      dir: "db/migrations"
      up_suffix: ".up.sql"
      down_suffix: ".down.sql"

Rule: creating a NEW up-migration under `dir` is denied unless the matching
down/rollback artifact already exists on disk, or is written by the same
operation (possible for a Bash command that writes both files).

Editing an existing migration is not affected. Writing the down file is never
blocked.

FAIL OPEN: unparseable config, unparseable command, or an unresolvable path
allows the operation. Exit 0 always.
"""

import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from _adlc_paths import deny, flag_active, normalize, to_project_relative
    from _adlc_bashparse import extract_write_targets
except Exception:
    sys.exit(0)

try:
    import yaml as yaml_lib
    HAS_YAML = True
except ImportError:
    HAS_YAML = False

CONFIG_PATHS = (
    ".sdlc/verification.yml",
    ".sdlc/verification.yaml",
    "verification.yml",
    "verification.yaml",
)


def _read_config_fallback(content):
    """Minimal parse of the migrations block when PyYAML is unavailable."""
    block = re.search(r"^migrations:\s*$(.*?)(?=^\S|\Z)", content,
                      re.MULTILINE | re.DOTALL)
    if not block:
        return None
    result = {}
    for key in ("dir", "up_suffix", "down_suffix"):
        match = re.search(
            r"^\s+%s:\s*[\"']?([^\"'\n#]+)[\"']?\s*$" % key,
            block.group(1), re.MULTILINE
        )
        if match:
            result[key] = match.group(1).strip()
    return result or None


def read_migration_config():
    """Return (dir, up_suffix, down_suffix) or None when not configured."""
    for path in CONFIG_PATHS:
        if not os.path.exists(path):
            continue
        try:
            with open(path) as f:
                content = f.read()
        except OSError:
            continue

        config = None
        if HAS_YAML:
            try:
                data = yaml_lib.safe_load(content)
                if isinstance(data, dict):
                    candidate = data.get("migrations")
                    if isinstance(candidate, dict):
                        config = candidate
            except Exception:
                config = None
        if config is None:
            config = _read_config_fallback(content)

        if not config:
            continue

        directory = str(config.get("dir", "")).strip()
        up_suffix = str(config.get("up_suffix", "")).strip()
        down_suffix = str(config.get("down_suffix", "")).strip()

        # Unfilled scaffold placeholders mean "not configured".
        if not directory or not up_suffix or not down_suffix:
            continue
        if any("{{" in v for v in (directory, up_suffix, down_suffix)):
            continue

        return normalize(directory).rstrip("/"), up_suffix, down_suffix

    return None


def under_dir(path, directory):
    normalized = normalize(path)
    return normalized == directory or normalized.startswith(directory + "/")


def check_targets(targets, config):
    """Return a deny reason for the first offending target, else None."""
    directory, up_suffix, down_suffix = config
    written = set(normalize(t) for t in targets)

    for target in targets:
        normalized = normalize(target)
        if not normalized or not under_dir(normalized, directory):
            continue
        if not normalized.endswith(up_suffix):
            continue
        # Only creation is guarded; editing an existing migration is fine.
        if os.path.exists(normalized):
            continue

        counterpart = normalized[:-len(up_suffix)] + down_suffix
        if counterpart in written:
            continue
        if os.path.exists(counterpart):
            continue

        return (
            f"Migration {os.path.basename(normalized)} has no rollback. "
            f"Create {os.path.basename(counterpart)} in the same operation, or "
            "before this one. Every forward migration needs a down migration — "
            "an un-rollbackable migration is a production incident waiting to happen. "
            "To disable enforcement: remove .sdlc/.enforce-migrations"
        )
    return None


def main():
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            sys.exit(0)
        hook_input = json.loads(raw)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    if not flag_active(".enforce-migrations"):
        sys.exit(0)

    config = read_migration_config()
    if not config:
        # Not configured in verification.yml — guard is inert by design.
        sys.exit(0)

    tool_input = hook_input.get("tool_input", {})
    if not isinstance(tool_input, dict):
        sys.exit(0)

    targets = []
    file_path = tool_input.get("file_path", "")
    if file_path:
        # Claude Code sends absolute paths; the configured migrations dir is
        # relative to the project root.
        targets.append(to_project_relative(file_path))

    command = tool_input.get("command", "")
    if command:
        try:
            targets.extend(extract_write_targets(command))
        except Exception:
            sys.exit(0)

    if not targets:
        sys.exit(0)

    reason = check_targets(targets, config)
    if reason:
        print(json.dumps(deny(reason)))
    sys.exit(0)


if __name__ == "__main__":
    main()
