#!/usr/bin/env bash
# ============================================================================
# hook-matrix.sh — behavioral test matrix for the ADLC-Solo PreToolUse guards.
#
# v3 registers exactly two guards, both on matcher "Edit|Write|Bash":
# guard-test-lock.py and guard-migrations.py. This matrix builds a throwaway
# git repo, feeds real hook JSON on stdin to both, and asserts the allow/deny
# decision for each case.
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

cleanup() { rm -rf "$TMP_ROOT"; }
trap cleanup EXIT

build_fixture() {
    mkdir -p "$REPO"
    cd "$REPO" || exit 1
    git init -q -b main .
    git config user.email "test@example.com"
    git config user.name "hook-matrix"

    mkdir -p src .sdlc db/migrations

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

    # verification.yml WITHOUT a migrations block — migrations guard starts inert.
    cat > verification.yml <<'EOF'
post_task:
  - name: "Build"
    command: "go build ./..."
EOF

    git add -A
    git commit -q -m "fixture"
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

# Both registered guards share one matcher, so Edit and Bash run the same pair.
REGISTERED_HOOKS=(guard-test-lock.py guard-migrations.py)

decide() {
    local cwd="$1" tool="$2" key="$3" value="$4"
    local payload hook
    payload=$(make_payload "$tool" "$key" "$value")
    for hook in "${REGISTERED_HOOKS[@]}"; do
        if [[ "$(run_hook "$hook" "$cwd" "$payload")" == "deny" ]]; then
            echo "deny"; return
        fi
    done
    echo "allow"
}

decide_edit() { decide "$1" "Edit" "file_path" "$2"; }
decide_bash() { decide "$1" "Bash" "command" "$2"; }

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

# --- No flags: both guards inert, everything is allowed --------------------
check_edit "no-flags" "$REPO" "src/main.go"                            "allow"
check_edit "no-flags" "$REPO" "src/main_test.go"                       "allow"
check_edit "no-flags" "$REPO" "README.md"                              "allow"
check_bash "no-flags" "$REPO" "cat > src/main.go"                      "allow"
check_bash "no-flags" "$REPO" "cat > src/main_test.go"                 "allow"
check_bash "no-flags" "$REPO" "npm install"                            "allow"
check_bash "no-flags" "$REPO" "go mod tidy"                            "allow"

# --- Test lock during bugfix ----------------------------------------------
touch "$REPO/.sdlc/.bugfix-active"

# Existing test file is locked; a NEW test file is the RED step and stays open.
check_edit "bugfix" "$REPO" "src/main_test.go"                         "deny"
check_edit "bugfix" "$REPO" "src/new_test.go"                          "allow"
# Absolute paths are what Claude Code actually sends.
check_edit "bugfix" "$REPO" "$REPO/src/main_test.go"                   "deny"
check_edit "bugfix" "$REPO" "$REPO/src/new_test.go"                    "allow"
# Production code and docs are not this guard's business.
check_edit "bugfix" "$REPO" "src/main.go"                              "allow"
check_edit "bugfix" "$REPO" "README.md"                                "allow"

# Bash bypass shapes must reach the same decision as the Edit path.
check_bash "bugfix" "$REPO" "cat > src/main_test.go"                   "deny"
check_bash "bugfix" "$REPO" "cat > src/new_test.go"                    "allow"
check_bash "bugfix" "$REPO" "tee src/main_test.go < /dev/null"         "deny"
check_bash "bugfix" "$REPO" "sed -i 's/a/b/' src/main_test.go"         "deny"
check_bash "bugfix" "$REPO" "echo x >> src/main_test.go"               "deny"
check_bash "bugfix" "$REPO" "cp /etc/hostname src/main_test.go"        "deny"
check_bash "bugfix" "$REPO" "dd if=/dev/zero of=src/main_test.go"      "deny"
check_bash "bugfix" "$REPO" "python3 -c \"open('src/main_test.go','w')\"" "deny"

# Fail-open: unresolvable targets are allowed, never denied.
check_bash "bugfix" "$REPO" 'echo x > $TARGET'                         "allow"
check_bash "bugfix" "$REPO" 'echo x > $(mktemp)'                       "allow"
check_bash "bugfix" "$REPO" "go test ./... > /dev/null 2>&1"           "allow"
check_bash "bugfix" "$REPO" "sed -n '1,5p' src/main_test.go"           "allow"
# A heredoc body containing a `>` must not be parsed as a redirection.
check_bash "bugfix" "$REPO" "$(printf 'cat > README.md <<EOF\nif a > b\nEOF')" "allow"

rm -f "$REPO/.sdlc/.bugfix-active"

# Flag gone -> inert again.
check_edit "no-bugfix" "$REPO" "src/main_test.go"                      "allow"
check_bash "no-bugfix" "$REPO" "cat > src/main_test.go"                "allow"

# --- Migration guard -------------------------------------------------------
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

# --- Both guards live at once ---------------------------------------------
touch "$REPO/.sdlc/.enforce-migrations"
touch "$REPO/.sdlc/.bugfix-active"
check_edit "both" "$REPO" "db/migrations/007_new.up.sql"              "deny"
check_edit "both" "$REPO" "src/main_test.go"                          "deny"
check_edit "both" "$REPO" "src/main.go"                               "allow"
rm -f "$REPO/.sdlc/.enforce-migrations" "$REPO/.sdlc/.bugfix-active"

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
