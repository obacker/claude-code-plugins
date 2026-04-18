#!/bin/bash
# PostToolUse hook — run a quick compile/type check on the edited file so
# compile errors surface within the current TDD cycle rather than 3 turns later.
#
# Outputs an advisory message to stderr when check fails (non-blocking).
# Always exits 0 — this is informational, not authoritative.
set -u

INPUT=$(cat 2>/dev/null || true)
[[ -z "$INPUT" ]] && exit 0

FILE_PATH=$(printf '%s' "$INPUT" | python3 -c "
import sys,json
try:
    e=json.load(sys.stdin)
    ti=e.get('tool_input',{}) or {}
    print(ti.get('file_path','') or ti.get('path','') or '')
except Exception:
    pass
" 2>/dev/null || true)

[[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]] && exit 0

# Skip ADLC artifacts and config files — they don't compile.
case "$FILE_PATH" in
  */.sdlc/*|.sdlc/*|*/.claude/*|.claude/*|*.md|*.json|*.yml|*.yaml|*.toml) exit 0 ;;
esac

advise() {
  # Non-blocking advisory — stderr is surfaced in agent context.
  echo "[compile-check] $1" >&2
}

EXT="${FILE_PATH##*.}"
case "$EXT" in
  go)
    if command -v go >/dev/null 2>&1; then
      PKG_DIR=$(dirname "$FILE_PATH")
      if ! go vet "./$PKG_DIR/..." 2>/dev/null; then
        advise "go vet failed for $PKG_DIR — review and fix before next TDD cycle."
      fi
    fi
    ;;
  ts|tsx)
    if command -v tsc >/dev/null 2>&1; then
      if ! tsc --noEmit --skipLibCheck "$FILE_PATH" 2>/dev/null; then
        advise "tsc --noEmit failed for $FILE_PATH — review and fix before next TDD cycle."
      fi
    fi
    ;;
  py)
    if command -v python3 >/dev/null 2>&1; then
      if ! python3 -c "import ast; ast.parse(open('$FILE_PATH').read())" 2>/dev/null; then
        advise "Python syntax check failed for $FILE_PATH — review and fix before next TDD cycle."
      fi
    fi
    ;;
esac

exit 0
