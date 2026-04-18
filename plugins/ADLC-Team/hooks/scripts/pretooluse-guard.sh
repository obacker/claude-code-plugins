#!/bin/bash
# PreToolUse guard: spec protection + worktree enforcement in a single bash process.
# Replaces protect-spec.py + enforce-worktree.py to cut Python fork overhead.
#
# Fast path: ADLC artifacts (.sdlc/, .claude/, root .md, common configs) → allow immediately.
# Spec check: inline test for *-spec.md + approval state in registry JSON.
# Worktree check: single `git rev-parse` comparison.
#
# Exit 0 + JSON permissionDecision on stdout. Fail-open on parse errors.

set -u

emit_allow() {
  printf '{"hookSpecificOutput":{"permissionDecision":"allow"}}\n'
  exit 0
}

emit_deny() {
  local reason="$1"
  # Escape backslashes and quotes for JSON
  reason=${reason//\\/\\\\}
  reason=${reason//\"/\\\"}
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$reason"
  exit 0
}

# ── Read JSON input from stdin ──────────────────────────────
INPUT=$(cat 2>/dev/null || true)
if [[ -z "$INPUT" ]]; then
  emit_allow
fi

# Extract file_path with lightweight jq-free parsing (python3 only if available — otherwise grep)
FILE_PATH=""
if command -v python3 >/dev/null 2>&1; then
  FILE_PATH=$(printf '%s' "$INPUT" | python3 -c "
import sys,json
try:
    e=json.load(sys.stdin)
    ti=e.get('tool_input',{}) or {}
    print(ti.get('file_path','') or ti.get('path','') or '')
except Exception:
    pass
" 2>/dev/null || true)
fi

if [[ -z "$FILE_PATH" ]]; then
  emit_allow
fi

# ── Fast path: ADLC artifacts always allowed ─────────────────
case "$FILE_PATH" in
  */.sdlc/*|.sdlc/*)           emit_allow ;;
  */.claude/*|.claude/*)       emit_allow ;;
esac

BASENAME=$(basename "$FILE_PATH")
case "$BASENAME" in
  CLAUDE.md|README.md|UPGRADING.md|CHANGELOG.md|LICENSE|LICENSE.md) emit_allow ;;
  package.json|tsconfig.json|pyproject.toml|go.mod|go.sum|Cargo.toml|Cargo.lock) emit_allow ;;
  .gitignore|.env.example|docker-compose.yml|Dockerfile|Makefile) emit_allow ;;
esac

# Root-level .md files → allowed (compare parent dir to repo toplevel)
if [[ "$FILE_PATH" == *.md ]]; then
  REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
  PARENT=$(cd "$(dirname "$FILE_PATH")" 2>/dev/null && pwd || true)
  if [[ -n "$REPO_ROOT" && "$PARENT" == "$REPO_ROOT" ]]; then
    emit_allow
  fi
fi

# ── Spec protection check ───────────────────────────────────
# If it's a spec file, consult the registry for approval state.
if [[ "$BASENAME" == *-spec.md && "$FILE_PATH" == *.sdlc* ]]; then
  SPEC_DIR=$(dirname "$FILE_PATH")
  STEM="${BASENAME%-spec.md}"
  REGISTRY=""
  if [[ -f "$SPEC_DIR/${STEM}-registry.json" ]]; then
    REGISTRY="$SPEC_DIR/${STEM}-registry.json"
  elif [[ -f "$SPEC_DIR/feature-registry.json" ]]; then
    REGISTRY="$SPEC_DIR/feature-registry.json"
  fi

  if [[ -n "$REGISTRY" ]]; then
    APPROVED=$(python3 -c "
import sys,json
try:
    d=json.load(open('$REGISTRY'))
    print('1' if d.get('spec_approved_at') else '0')
except Exception:
    print('0')
" 2>/dev/null || echo "0")
    if [[ "$APPROVED" == "1" ]]; then
      emit_deny "Spec '$BASENAME' is approved and immutable. ACs cannot be modified after approval. To change requirements, create a new spec or request re-approval."
    fi
  fi
  # Not tracked or not approved → fall through (spec files outside approval are editable)
  emit_allow
fi

# ── Worktree enforcement check ──────────────────────────────
# Production/test code: require git worktree (not main checkout).
COMMON_DIR=$(git rev-parse --git-common-dir 2>/dev/null || true)
GIT_DIR=$(git rev-parse --git-dir 2>/dev/null || true)

if [[ -z "$COMMON_DIR" || -z "$GIT_DIR" ]]; then
  # Not in a git repo — allow (not our concern)
  emit_allow
fi

if [[ "$COMMON_DIR" != "$GIT_DIR" ]]; then
  # We're in a worktree — allow
  emit_allow
fi

# Main checkout, non-ADLC file → deny
emit_deny "Cannot edit '$BASENAME' from main conversation. Production and test code must be edited inside a worktree. Spawn a dev-agent (isolation: worktree) or qa-agent (isolation: worktree) to make this change."
