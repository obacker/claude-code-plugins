#!/usr/bin/env bash
# ============================================================================
# hook-matrix.sh — behavioral test matrix for the ADLC-Solo PreToolUse guards.
#
# Builds a throwaway git repo (approved spec + worktree + opt-in flags), feeds
# real hook JSON on stdin to the same set of hooks that hooks.json registers
# for each tool, and asserts the allow/deny decision.
#
# Whitespace note: python json.dumps emits `": "` with a space, bash printf
# emits `":"` without. Every decision is matched against output with ALL
# whitespace stripped, so assertions cannot silently pass on a formatting
# difference.
#
# Usage: bash tests/hook-matrix.sh
# Exits non-zero on any mismatch.
# ============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS="$(dirname "$SCRIPT_DIR")/hooks/scripts"

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
DIM=$'\033[2m'
NC=$'\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
ROWS=()

# ---------------------------------------------------------------------------
# Fixture
# ---------------------------------------------------------------------------
TMP_ROOT="$(mktemp -d)"
REPO="$TMP_ROOT/repo"
WORKTREE="$TMP_ROOT/wt"

cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

build_fixture() {
    mkdir -p "$REPO"
    cd "$REPO" || exit 1
    git init -q -b main .
    git config user.email "test@example.com"
    git config user.name "hook-matrix"

    mkdir -p src .sdlc/milestones/M1 db/migrations

    cat > src/main.go <<'EOF'
package main

func main() {}
EOF
    cat > src/main_test.go <<'EOF'
package main

import "testing"

func TestMain_Smoke(t *testing.T) {}
EOF
    echo "# Fixture" > README.md

    cat > .sdlc/milestones/M1/milestone-spec.md <<'EOF'
# Milestone M1

## AC-1
Given a thing, when it happens, then it works.
EOF

    # spec_approved_at set — this is what makes the spec immutable.
    cat > .sdlc/milestones/M1/feature-registry.json <<'EOF'
{
  "milestone_id": "M1",
  "spec_approved_at": "2026-01-01T00:00:00Z",
  "acceptance_criteria": [
    {"id": "AC-1", "passes": false}
  ]
}
EOF

    # verification.yml WITHOUT a migrations block — migrations guard starts inert.
    cat > verification.yml <<'EOF'
post_task:
  - name: "Build"
    command: "go build ./..."
EOF

    # Opt-in flag for worktree enforcement. Committed so the worktree gets it.
    touch .sdlc/.enforce-worktree

    git add -A
    git commit -q -m "fixture"

    git worktree add -q -b feature/test "$WORKTREE" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Hook plumbing
# ---------------------------------------------------------------------------

# Build a PreToolUse payload. $1=tool_name, $2=key (file_path|command), $3=value
make_payload() {
    python3 -c '
import json, sys
tool, key, value = sys.argv[1], sys.argv[2], sys.argv[3]
print(json.dumps({
    "session_id": "test",
    "hook_event_name": "PreToolUse",
    "tool_name": tool,
    "tool_input": {key: value},
}))' "$1" "$2" "$3"
}

# Run one hook. Echoes "deny" or "allow".
run_hook() {
    local hook="$1" cwd="$2" payload="$3"
    local out
    out=$(cd "$cwd" && printf '%s' "$payload" | python3 "$HOOKS/$hook" 2>/dev/null)
    # Strip ALL whitespace before matching so `": "` and `":"` both match.
    if printf '%s' "$out" | tr -d '[:space:]' | grep -qF '"permissionDecision":"deny"'; then
        echo "deny"
    else
        echo "allow"
    fi
}

# Decision for an Edit/Write, running exactly the hooks hooks.json registers
# for the Edit|Write and Edit|Write|Bash matchers.
decide_edit() {
    local cwd="$1" file_path="$2"
    local payload
    payload=$(make_payload "Edit" "file_path" "$file_path")
    for hook in protect-spec.py enforce-worktree.py guard-migrations.py guard-test-lock.py; do
        if [[ "$(run_hook "$hook" "$cwd" "$payload")" == "deny" ]]; then
            echo "deny"; return
        fi
    done
    echo "allow"
}

# Decision for a Bash command, running the Bash and Edit|Write|Bash matchers.
decide_bash() {
    local cwd="$1" command="$2"
    local payload
    payload=$(make_payload "Bash" "command" "$command")
    for hook in guard-bash-write.py guard-migrations.py guard-test-lock.py; do
        if [[ "$(run_hook "$hook" "$cwd" "$payload")" == "deny" ]]; then
            echo "deny"; return
        fi
    done
    echo "allow"
}

# assert <context> <tool> <subject> <expected> <actual>
assert_row() {
    local context="$1" tool="$2" subject="$3" expected="$4" actual="$5"
    local status
    # Rows are newline-delimited records; a multi-line command (heredoc) would
    # otherwise be truncated at the first line when the row is read back.
    subject="${subject//$'\n'/ \\n }"
    if [[ "$expected" == "$actual" ]]; then
        status="PASS"; PASS_COUNT=$((PASS_COUNT + 1))
    else
        status="FAIL"; FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    ROWS+=("$context|$tool|$subject|$expected|$actual|$status")
}

check_edit() { assert_row "$1" "Edit" "$3" "$4" "$(decide_edit "$2" "$3")"; }
check_bash() { assert_row "$1" "Bash" "$3" "$4" "$(decide_bash "$2" "$3")"; }

# ---------------------------------------------------------------------------
# Matrix
# ---------------------------------------------------------------------------
build_fixture

# --- Core matrix (the acceptance criteria) --------------------------------
check_edit "main"     "$REPO" ".sdlc/milestones/M1/milestone-spec.md" "deny"
check_edit "main"     "$REPO" "src/main.go"                           "deny"
check_edit "main"     "$REPO" "src/main_test.go"                      "allow"
check_edit "main"     "$REPO" "README.md"                             "allow"
check_bash "main"     "$REPO" "cat > src/main.go"                     "deny"
check_bash "main"     "$REPO" "cat > src/x_test.go"                   "allow"
check_bash "main"     "$REPO" "npm install"                           "allow"
check_bash "main"     "$REPO" "go mod tidy"                           "allow"
check_edit "worktree" "$WORKTREE" "src/main.go"                       "allow"
check_bash "worktree" "$WORKTREE" "cat > src/main.go"                 "allow"

# --- Absolute paths (what Claude Code actually sends) ---------------------
check_edit "main"     "$REPO" "$REPO/src/main.go"                     "deny"
check_edit "main"     "$REPO" "$REPO/src/main_test.go"                "allow"

# --- Bash bypass shapes (F7) ----------------------------------------------
check_bash "main" "$REPO" "tee src/main.go < /dev/null"               "deny"
check_bash "main" "$REPO" "sed -i 's/a/b/' src/main.go"               "deny"
check_bash "main" "$REPO" "echo x >> src/main.go"                     "deny"
check_bash "main" "$REPO" "cp /etc/hostname src/main.go"              "deny"
check_bash "main" "$REPO" "dd if=/dev/zero of=src/main.go"            "deny"
check_bash "main" "$REPO" "python3 -c \"open('src/main.go','w')\""    "deny"
check_bash "main" "$REPO" "cat > .sdlc/milestones/M1/milestone-spec.md" "deny"

# --- Fail-open: unresolvable targets must be allowed, never denied --------
check_bash "main" "$REPO" 'echo x > $TARGET'                          "allow"
check_bash "main" "$REPO" 'echo x > $(mktemp)'                        "allow"
check_bash "main" "$REPO" "go test ./... > /dev/null 2>&1"            "allow"
check_bash "main" "$REPO" "sed -n '1,5p' src/main.go"                 "allow"
# Heredoc body containing a `>` must not be parsed as a redirection.
check_bash "main" "$REPO" "$(printf 'cat > README.md <<EOF\nif a > b\nEOF')" "allow"

# --- no-flag: enforcement off means everything is allowed ------------------
mv "$REPO/.sdlc/.enforce-worktree" "$TMP_ROOT/.flag-parked"
check_edit "no-flag" "$REPO" "src/main.go"                            "allow"
check_bash "no-flag" "$REPO" "cat > src/main.go"                      "allow"
# Spec immutability is NOT flag-gated — it holds on both paths regardless.
check_edit "no-flag" "$REPO" ".sdlc/milestones/M1/milestone-spec.md"  "deny"
check_bash "no-flag" "$REPO" "cat > .sdlc/milestones/M1/milestone-spec.md" "deny"
mv "$TMP_ROOT/.flag-parked" "$REPO/.sdlc/.enforce-worktree"

# --- C7b: test lock during bugfix -----------------------------------------
# Flag absent first: editing an existing test is allowed.
check_edit "no-bugfix" "$REPO" "src/main_test.go"                     "allow"

touch "$REPO/.sdlc/.bugfix-active"
check_edit "bugfix"  "$REPO" "src/main_test.go"                       "deny"
check_edit "bugfix"  "$REPO" "src/new_test.go"                        "allow"
check_bash "bugfix"  "$REPO" "cat > src/main_test.go"                 "deny"
check_bash "bugfix"  "$REPO" "cat > src/new_test.go"                  "allow"
check_bash "bugfix"  "$REPO" "sed -i 's/a/b/' src/main_test.go"       "deny"
# Non-test files are untouched by this guard (worktree guard still applies).
check_edit "bugfix"  "$REPO" "README.md"                              "allow"
rm -f "$REPO/.sdlc/.bugfix-active"

# --- C7a: migration guard --------------------------------------------------
# Park the worktree flag: migration rows must isolate the migration guard.
# Migration files are production code, so enforce-worktree would deny them all
# from the main checkout and mask what this section is actually testing.
mv "$REPO/.sdlc/.enforce-worktree" "$TMP_ROOT/.flag-parked"

# Flag present, verification.yml has NO migrations block -> inert.
touch "$REPO/.sdlc/.enforce-migrations"
check_edit "mig-unconfigured" "$REPO" "db/migrations/001_init.up.sql" "allow"
check_bash "mig-unconfigured" "$REPO" "cat > db/migrations/001_init.up.sql" "allow"

# Now configure it.
cat >> "$REPO/verification.yml" <<'EOF'

migrations:
  dir: "db/migrations"
  up_suffix: ".up.sql"
  down_suffix: ".down.sql"
EOF

check_edit "mig" "$REPO" "db/migrations/001_init.up.sql"              "deny"
check_bash "mig" "$REPO" "cat > db/migrations/001_init.up.sql"        "deny"
check_edit "mig" "$REPO" "$REPO/db/migrations/001_init.up.sql"        "deny"
# Writing the down artifact itself is never blocked.
check_edit "mig" "$REPO" "db/migrations/001_init.down.sql"            "allow"
# Both files written by the same Bash command -> allowed.
check_bash "mig" "$REPO" "touch db/migrations/002_x.down.sql > db/migrations/002_x.down.sql; cat > db/migrations/002_x.up.sql" "allow"
# Outside the configured dir -> not this guard's business.
check_edit "mig" "$REPO" "db/other/003_x.up.sql"                      "allow"

# Down artifact already on disk -> allowed.
touch "$REPO/db/migrations/004_ok.down.sql"
check_edit "mig" "$REPO" "db/migrations/004_ok.up.sql"                "allow"

# Editing an EXISTING up migration is not a creation -> allowed.
touch "$REPO/db/migrations/005_existing.up.sql"
check_edit "mig" "$REPO" "db/migrations/005_existing.up.sql"          "allow"

# Configured but flag absent -> inert.
rm -f "$REPO/.sdlc/.enforce-migrations"
check_edit "mig-noflag" "$REPO" "db/migrations/006_new.up.sql"        "allow"
check_bash "mig-noflag" "$REPO" "cat > db/migrations/006_new.up.sql"  "allow"

mv "$TMP_ROOT/.flag-parked" "$REPO/.sdlc/.enforce-worktree"

# With BOTH guards live, worktree isolation still covers migration files.
touch "$REPO/.sdlc/.enforce-migrations"
check_edit "mig+worktree" "$REPO" "db/migrations/007_new.up.sql"      "deny"
rm -f "$REPO/.sdlc/.enforce-migrations"

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
cd "$SCRIPT_DIR" || true

printf '\n'
printf '%-18s %-6s %-52s %-8s %-8s %s\n' "CONTEXT" "TOOL" "FILE / COMMAND" "EXPECT" "ACTUAL" "RESULT"
printf '%s\n' "$(printf '%.0s-' {1..104})"

for row in "${ROWS[@]}"; do
    IFS='|' read -r context tool subject expected actual status <<< "$row"
    # Keep the table readable when a fixture path is long.
    display="${subject//$REPO/\$REPO}"
    display="${display//$WORKTREE/\$WT}"
    if [[ ${#display} -gt 52 ]]; then
        display="${display:0:49}..."
    fi
    if [[ "$status" == "PASS" ]]; then
        printf '%-18s %-6s %-52s %-8s %-8s %s%s%s\n' \
            "$context" "$tool" "$display" "$expected" "$actual" "$GREEN" "$status" "$NC"
    else
        printf '%-18s %-6s %-52s %-8s %-8s %s%s%s\n' \
            "$context" "$tool" "$display" "$expected" "$actual" "$RED" "$status" "$NC"
    fi
done

printf '%s\n' "$(printf '%.0s-' {1..104})"
TOTAL=$((PASS_COUNT + FAIL_COUNT))
if [[ "$FAIL_COUNT" -eq 0 ]]; then
    printf '%s%d/%d passed%s\n\n' "$GREEN" "$PASS_COUNT" "$TOTAL" "$NC"
    exit 0
else
    printf '%s%d/%d passed, %d FAILED%s\n\n' "$RED" "$PASS_COUNT" "$TOTAL" "$FAIL_COUNT" "$NC"
    printf '%sHook scripts under test: %s%s\n\n' "$DIM" "$HOOKS" "$NC"
    exit 1
fi
