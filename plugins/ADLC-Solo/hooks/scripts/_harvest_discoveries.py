#!/usr/bin/env python3
"""
Reads a SubagentStop payload on stdin, prints the body of the agent report's
"## Discoveries" section (if any) on stdout. Prints nothing otherwise.

Lives in its own file rather than inline in on-agent-stop.sh because the
regex contains `$(` , which bash would treat as command substitution inside a
double-quoted `python3 -c` string.
"""

import json
import re
import sys

SECTION_RE = re.compile(
    r"^#{2,3}\s*Discoveries\s*$(.*?)(?=^#{1,3}\s|\Z)",
    re.MULTILINE | re.DOTALL,
)


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return
    if not isinstance(data, dict):
        return

    message = data.get("last_assistant_message") or ""
    if not isinstance(message, str) or not message:
        return

    match = SECTION_RE.search(message)
    if not match:
        return

    body = match.group(1).strip()
    if body:
        sys.stdout.write(body + "\n")


if __name__ == "__main__":
    main()
