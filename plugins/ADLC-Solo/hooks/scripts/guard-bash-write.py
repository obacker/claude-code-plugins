#!/usr/bin/env python3
"""
PreToolUse hook (matcher: Bash): closes the Bash file-write bypass.

The Edit|Write guards (protect-spec.py, enforce-worktree.py) never see a file
written through the Bash tool — `cat > f`, `tee`, `sed -i`, `>>`, `cp`, `dd`.
This hook applies the same two rules to Bash write destinations.

Rules:
  1. Approved-spec immutability — always on, mirroring protect-spec.py, which
     is likewise not flag-gated. Gating it would leave the Bash bypass open on
     every project that has not opted into worktrees.
  2. Worktree isolation — active only when .sdlc/.enforce-worktree exists,
     the same opt-in as enforce-worktree.py, with the same exemption rules.

FAIL OPEN: a command whose write destinations cannot be confidently resolved
is allowed. See _adlc_bashparse.py for what counts as confident.

Exit 0 always — the decision is in the JSON output.
"""

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from _adlc_paths import (
        deny, flag_active, is_exempt_from_worktree, is_in_worktree,
        is_spec_approved_for_file, is_spec_file,
    )
    from _adlc_bashparse import extract_write_targets
except Exception:
    # A hook must never hard-fail. No guard is better than a broken guard.
    sys.exit(0)


def main():
    try:
        raw = sys.stdin.read()
        if not raw.strip():
            sys.exit(0)
        hook_input = json.loads(raw)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    tool_input = hook_input.get("tool_input", {})
    if not isinstance(tool_input, dict):
        sys.exit(0)

    command = tool_input.get("command", "")
    if not command:
        sys.exit(0)

    try:
        targets = extract_write_targets(command)
    except Exception:
        sys.exit(0)

    if not targets:
        sys.exit(0)

    # --- Rule 1: approved specs are immutable, on every path ---
    for target in targets:
        if is_spec_file(target) and is_spec_approved_for_file(target):
            print(json.dumps(deny(
                f"Spec is approved and immutable ({os.path.basename(target)}). "
                "Acceptance criteria cannot be modified after user approval, "
                "and writing through Bash is not a way around that. "
                "If the spec needs changes, the user must explicitly re-approve. "
                "Report this to the orchestrator — do not attempt to bypass."
            )))
            sys.exit(0)

    # --- Rule 2: worktree isolation, opt-in ---
    if not flag_active(".enforce-worktree"):
        sys.exit(0)

    if is_in_worktree():
        sys.exit(0)

    blocked = [t for t in targets if not is_exempt_from_worktree(t)]
    if not blocked:
        sys.exit(0)

    names = ", ".join(os.path.basename(t) for t in blocked)
    print(json.dumps(deny(
        f"Cannot write production code ({names}) from the main checkout via Bash. "
        "ADLC requires production code changes in an isolated worktree via dev-agent. "
        "This is the same rule the Edit/Write guard enforces — Bash is not an exemption. "
        "Delegate this write to a dev-agent with isolation: worktree. "
        "To disable enforcement: remove .sdlc/.enforce-worktree"
    )))
    sys.exit(0)


if __name__ == "__main__":
    main()
