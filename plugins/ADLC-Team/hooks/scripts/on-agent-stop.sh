#!/bin/bash
# SubagentStop hook — validate agent work (fast, synchronous) + auto-harvest
# discoveries (slow, async background). Exit 0 always.
set -uo pipefail
# Intentionally no -e: missing .sdlc/ subdirs are normal early in a project
# and must not abort the hook. Each command below handles its own error path.

SDLC_DIR=".sdlc"
LOG_FILE="$SDLC_DIR/agent-log.txt"
KNOWLEDGE_FILE="$SDLC_DIR/KNOWLEDGE.md"
mkdir -p "$SDLC_DIR"

INPUT=$(cat)

# Official SubagentStop schema: agent_type, agent_id, stop_hook_active,
# last_assistant_message, agent_transcript_path. No exit_code field exists.
STOP_HOOK_ACTIVE=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('stop_hook_active',False))" 2>/dev/null || echo "False")
if [[ "$STOP_HOOK_ACTIVE" == "True" ]]; then
  # Avoid infinite loops if a continuation is already in flight.
  exit 0
fi

AGENT_TYPE=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('agent_type','unknown'))" 2>/dev/null || echo "unknown")
AGENT_ID=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('agent_id','unknown'))" 2>/dev/null || echo "unknown")

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DATE_SHORT=$(date -u +"%Y-%m-%d")
echo "$TIMESTAMP $AGENT_TYPE INFO completed agent_id=$AGENT_ID" >> "$LOG_FILE"

# ── Agent-specific validation (fast — stays synchronous) ────
case "$AGENT_TYPE" in
  dev-agent)
    BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
    if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
      echo "$TIMESTAMP dev-agent WARN completed on main branch — expected feature branch" >> "$LOG_FILE"
    else
      COMMITS_AHEAD=$(git rev-list --count "origin/main..HEAD" 2>/dev/null || git rev-list --count "origin/master..HEAD" 2>/dev/null || echo "0")
      echo "$TIMESTAMP dev-agent INFO branch=$BRANCH commits_ahead=$COMMITS_AHEAD" >> "$LOG_FILE"
    fi
    PROGRESS_FILES=$(find "$SDLC_DIR/_active/" -name "*.progress.md" -newer "$LOG_FILE" 2>/dev/null | wc -l)
    if [[ "$PROGRESS_FILES" -eq 0 ]]; then
      echo "$TIMESTAMP dev-agent WARN no progress file updated this session" >> "$LOG_FILE"
    fi
    ;;
  qa-agent)
    QA_REPORTS=$(find "$SDLC_DIR/reviews/" -name "*-report.md" -newer "$LOG_FILE" 2>/dev/null | wc -l)
    if [[ "$QA_REPORTS" -eq 0 ]]; then
      echo "$TIMESTAMP qa-agent WARN no QA report created this session" >> "$LOG_FILE"
    fi
    ;;
  ba-agent)
    SPEC_FILES=$(find "$SDLC_DIR/specs/" -name "*-spec.md" -newer "$LOG_FILE" 2>/dev/null | wc -l)
    echo "$TIMESTAMP ba-agent INFO specs_created=$SPEC_FILES" >> "$LOG_FILE"
    ;;
esac

# ── Async KNOWLEDGE harvest (backgrounded — don't block next tool call) ──
harvest_knowledge() {
  if [[ -d "$SDLC_DIR/_active" && -f "$KNOWLEDGE_FILE" ]]; then
    for pf in "$SDLC_DIR/_active/"*.progress.md; do
      [[ -f "$pf" ]] || continue
      FEAT_ID=$(basename "$pf" .progress.md)

      DISCOVERIES=$(sed -n '/^## Discoveries/,/^## /{/^## Discoveries/d;/^## /d;p;}' "$pf" 2>/dev/null || true)

      if [[ -n "$DISCOVERIES" && "$DISCOVERIES" =~ [a-zA-Z] ]]; then
        FIRST_LINE=$(echo "$DISCOVERIES" | head -1 | tr -d '[:space:]' | cut -c1-40)
        if ! grep -qF "$FIRST_LINE" "$KNOWLEDGE_FILE" 2>/dev/null; then
          {
            echo ""
            echo "### [$DATE_SHORT] $FEAT_ID ($AGENT_TYPE)"
            echo "$DISCOVERIES"
          } >> "$KNOWLEDGE_FILE"
          echo "$TIMESTAMP $AGENT_TYPE INFO harvested discoveries from $FEAT_ID to KNOWLEDGE.md" >> "$LOG_FILE"
        fi
      fi
    done
  fi
}

# Fork harvest to background, detach, return immediately.
( harvest_knowledge > /dev/null 2>&1 ) &
disown 2>/dev/null || true

exit 0
