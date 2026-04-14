#!/bin/bash
# SubagentStop hook — validate agent work + auto-harvest discoveries to KNOWLEDGE.md.
# Exit 0 always — agent already finished, can only log.
set -euo pipefail

SDLC_DIR=".sdlc"
LOG_FILE="$SDLC_DIR/agent-log.txt"
KNOWLEDGE_FILE="$SDLC_DIR/KNOWLEDGE.md"
mkdir -p "$SDLC_DIR"

# Read JSON input
INPUT=$(cat)
AGENT_NAME=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('agent_name','unknown'))" 2>/dev/null || echo "unknown")
EXIT_CODE=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('exit_code',0))" 2>/dev/null || echo "0")

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
DATE_SHORT=$(date -u +"%Y-%m-%d")
echo "$TIMESTAMP $AGENT_NAME INFO completed with exit code $EXIT_CODE" >> "$LOG_FILE"

# ── Agent-specific validation (logging only) ─────────────────
case "$AGENT_NAME" in
  dev-agent)
    BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
    if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
      echo "$TIMESTAMP dev-agent WARN completed on main branch — expected feature branch" >> "$LOG_FILE"
    else
      COMMITS_AHEAD=$(git rev-list --count "origin/main..HEAD" 2>/dev/null || git rev-list --count "origin/master..HEAD" 2>/dev/null || echo "0")
      echo "$TIMESTAMP dev-agent INFO branch=$BRANCH commits_ahead=$COMMITS_AHEAD" >> "$LOG_FILE"
    fi
    # Check progress file updated
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

# ── Auto-harvest discoveries to KNOWLEDGE.md ─────────────────
# Scan progress files for ## Discoveries sections and append new entries
if [[ -d "$SDLC_DIR/_active" && -f "$KNOWLEDGE_FILE" ]]; then
  for pf in "$SDLC_DIR/_active/"*.progress.md; do
    [[ -f "$pf" ]] || continue
    FEAT_ID=$(basename "$pf" .progress.md)

    # Extract discoveries section (lines between "## Discoveries" and next "##" or EOF)
    DISCOVERIES=$(sed -n '/^## Discoveries/,/^## /{/^## Discoveries/d;/^## /d;p;}' "$pf" 2>/dev/null || true)

    if [[ -n "$DISCOVERIES" && "$DISCOVERIES" =~ [a-zA-Z] ]]; then
      # Check if already harvested (avoid duplicates)
      FIRST_LINE=$(echo "$DISCOVERIES" | head -1 | tr -d '[:space:]' | cut -c1-40)
      if ! grep -qF "$FIRST_LINE" "$KNOWLEDGE_FILE" 2>/dev/null; then
        {
          echo ""
          echo "### [$DATE_SHORT] $FEAT_ID ($AGENT_NAME)"
          echo "$DISCOVERIES"
        } >> "$KNOWLEDGE_FILE"
        echo "$TIMESTAMP $AGENT_NAME INFO harvested discoveries from $FEAT_ID to KNOWLEDGE.md" >> "$LOG_FILE"
      fi
    fi
  done
fi

exit 0
