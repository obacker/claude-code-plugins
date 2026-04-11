#!/usr/bin/env bash
# ============================================================================
# SubagentStop hook: validates agent work after completion.
#
# Reads agent name from stdin JSON. Performs post-completion checks
# specific to each agent type. Logs results to .sdlc/agent-log.txt.
# Surfaces warnings to stdout so the orchestrator can see them.
#
# Exit 0 always — agent already finished, can't block. Only log.
# ============================================================================

set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Parse agent name and exit code from JSON input
AGENT_NAME=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('agent_name', data.get('name', 'unknown')))
except:
    print('unknown')
" 2>/dev/null || echo "unknown")

EXIT_CODE=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('exit_code', 0))
except:
    print(0)
" 2>/dev/null || echo "0")

# Setup logging
LOG_DIR=".sdlc"
LOG_FILE="$LOG_DIR/agent-log.txt"
mkdir -p "$LOG_DIR"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

log_event() {
    echo "[$TIMESTAMP] [$AGENT_NAME] $1" >> "$LOG_FILE"
    # Surface warnings to orchestrator via stdout
    if [[ "$1" == *WARNING* ]]; then
        echo "⚠ AGENT WARNING [$AGENT_NAME]: $1"
    fi
}

# Agent-specific validation
case "$AGENT_NAME" in
    dev-agent)
        # Check: branch should have commits (not on main/master)
        CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
        if [[ "$CURRENT_BRANCH" == "main" || "$CURRENT_BRANCH" == "master" ]]; then
            log_event "WARNING: finished on $CURRENT_BRANCH — expected feature branch"
        elif [[ "$CURRENT_BRANCH" == "unknown" ]]; then
            log_event "WARNING: not in a git repository"
        else
            # Count commits ahead of main
            MAIN_BRANCH="main"
            if ! git rev-parse --verify "main" &>/dev/null; then
                MAIN_BRANCH="master"
            fi
            COMMIT_COUNT=$(git rev-list --count "$MAIN_BRANCH..HEAD" 2>/dev/null || echo "0")
            if [[ "$COMMIT_COUNT" == "0" ]]; then
                log_event "WARNING: 0 commits on branch $CURRENT_BRANCH — did the agent commit?"
            else
                log_event "OK: $COMMIT_COUNT commit(s) on $CURRENT_BRANCH"
            fi
        fi

        # Check: feature-registry.json updated
        REGISTRIES=$(find .sdlc/milestones -name "feature-registry.json" 2>/dev/null || true)
        if [[ -n "$REGISTRIES" ]]; then
            # Check if any registry was modified in last 10 minutes
            RECENT=$(find .sdlc/milestones -name "feature-registry.json" -mmin -10 2>/dev/null || true)
            if [[ -z "$RECENT" ]]; then
                log_event "WARNING: feature-registry.json not updated recently"
            else
                log_event "OK: feature-registry.json updated"
            fi
        fi
        ;;

    qa-spec-checker|qa-adversarial)
        # Check: test files should be committed
        UNSTAGED_TESTS=$(git diff --name-only -- '*test*' '*spec*' '*.test.*' '*.spec.*' 2>/dev/null | head -5)
        if [[ -n "$UNSTAGED_TESTS" ]]; then
            log_event "WARNING: uncommitted test files: $UNSTAGED_TESTS"
        else
            log_event "OK: test files committed"
        fi
        ;;

    spec-writer)
        # Check: milestone-spec.md should exist
        SPEC_FILES=$(find .sdlc/milestones -name "milestone-spec.md" 2>/dev/null || true)
        if [[ -z "$SPEC_FILES" ]]; then
            log_event "WARNING: no milestone-spec.md found after spec-writer completed"
        else
            # Check: feature-registry.json should also exist
            REGISTRY_FILES=$(find .sdlc/milestones -name "feature-registry.json" 2>/dev/null || true)
            if [[ -z "$REGISTRY_FILES" ]]; then
                log_event "WARNING: milestone-spec.md exists but feature-registry.json missing"
            else
                log_event "OK: milestone-spec.md + feature-registry.json created"
            fi
        fi
        ;;

    *)
        log_event "INFO: completed with exit code $EXIT_CODE"
        ;;
esac

exit 0
