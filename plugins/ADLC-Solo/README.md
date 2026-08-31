# ADLC v13 — Agent-Driven Lifecycle

Structured feature development for Claude Code: BDD specs, TDD implementation, automated review, and verification gates.

## What's New in v2.3.0

- **Bash write bypass closed** — the two PreToolUse guards only matched `Edit|Write`, so writing a file through the Bash tool (`cat > f`, `tee`, `sed -i`, `>>`, `cp`, `dd`) skipped worktree isolation and spec immutability entirely. A new `guard-bash-write.py` covers the `Bash` matcher. It fails open on anything it cannot parse confidently — see [Known gaps](#known-gaps).
- **`adlc-init --vendor`** — copies `agents/`, `skills/` and `hooks/` into the project's `.claude/` and merges hook entries into `.claude/settings.json` with repo-relative paths. This is what makes ADLC work in Claude Code cloud sessions, which load the repo's `.claude/` but not user-level installed plugins. The merge preserves existing keys and hook entries.
- **`adlc-init` now actually writes `.claude/settings.json`** — it never did for Go, TypeScript, JavaScript, Python or Rust projects. The `sed` filling the template used `s|...|...|` while the substituted command contains a literal pipe, so `sed` aborted and `set -e` killed the run. The `env` block promised in v2.1.0 therefore never reached those projects. See [UPGRADING.md](UPGRADING.md).
- **Two new opt-in guards** — `.sdlc/.enforce-migrations` (a new up-migration needs a down artifact) and `.sdlc/.bugfix-active` (existing test files are locked during a bugfix, new ones still allowed). Both are off unless you create the flag.
- **`SessionEnd` context snapshot** — `save-context.sh` now runs on `SessionEnd` as well as `PreCompact`.
- **Async discovery harvest** — `on-agent-stop.sh` forks and disowns the `## Discoveries` harvest into `CAPTURES.md`, so the hook returns immediately.
- **Corrected enforcement table** — the previous table claimed platform-level blocking for both PreToolUse hooks without qualification. That was false on the Bash path. Every row now states its actual matcher coverage.
- **Commands table replaced** — the README documented eight `/adlc:*` commands, but this plugin has no `commands/` directory. They are skills, and are now documented as such.

## What's New in v2.2.0

- **AI Collaboration Principles** — scaffold `CLAUDE.md` now carries an explicit 4-principle block that names the behaviors the existing ADLC mechanics (specs, TDD, worktrees, gates) already assume: think before coding, simplicity first, surgical changes, define success criteria. The same block is embedded as a short `Collaboration Principles` section in every agent prompt (spec-writer, dev-agent, qa-spec-checker, qa-adversarial). Existing projects: copy the new section from `scaffold/CLAUDE.md` into your project's `CLAUDE.md` — see [UPGRADING.md](UPGRADING.md).

## What's New in v2.1.0

- **Performance env vars actually work** — `adlc-init` now writes `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=75` and `CLAUDE_CODE_MAX_OUTPUT_TOKENS=16000` into `.claude/settings.json`. Previously these were documented in `CLAUDE.md` but never set. Existing projects: see [Upgrading](#upgrading).
- **Removed fake env var** — `MAX_THINKING_TOKENS` was documented but does not exist in the Claude Code binary. Removed from scaffold.

## What's New in v13 (v2.0.0)

- **Smart router** (`/adlc`) — Auto-detects project state and routes to the right workflow
- **PostToolUse compile-check** — Automatic `go vet` / `tsc --noEmit` after every Edit/Write on source files
- **Coverage gates** — Dev-agent enforces 85% coverage threshold with max 3 retry attempts
- **Anti-drift rules** — Dev-agent has turn-10/turn-15 progress gates and context discipline
- **Auto-retry on agent failure** — Orchestrator retries tool-limit/merge-conflict failures (max 2 retries)
- **QA agent split** — qa-spec-checker (Haiku, platform-enforced) + qa-adversarial (Sonnet, platform-enforced) replace single qa-tester
- **Task sizing for 35-turn budget** — plan-slice now sizes tasks to fit dev-agent's tighter turn limit
- **State machine gates** — Hard verification commands at every phase transition in build-feature
- **Warning surfacing** — SubagentStop hook outputs warnings to stdout (not just log file)
- **Tighter turn budgets** — dev-agent 35 turns (was 50), qa-spec-checker 20 turns, qa-adversarial 25 turns
- **Convention fixes** — YAML array tools in agent frontmatter, statusMessage on all hooks, explicit agents array in plugin.json

## What It Does

ADLC enforces a disciplined development lifecycle:

1. **Specification** — BDD acceptance criteria written by a specialized spec-writer agent (Opus)
2. **Planning** — Features decomposed into parallel-friendly implementation tasks
3. **Implementation** — Each task runs in an isolated worktree with strict TDD (iron law: no code without a failing test)
4. **Review** — Two-stage: spec compliance (qa-spec-checker/Haiku), then adversarial (qa-adversarial/Sonnet), then code quality (pr-review-toolkit)
5. **Verification** — Automated gates from verification.yml, feature-registry cross-checks, state machine enforcement
6. **Knowledge Capture** — Updates session-context.md, CAPTURES.md, domain files, and auto-memory with learnings

After spec approval, acceptance criteria become **immutable** — enforced by a PreToolUse hook that blocks edits. Agents that approach their turn limit commit partial work and report DONE_WITH_CONCERNS — the orchestrator spawns a continuation agent automatically.

## Install

```bash
# Install ADLC Solo
/plugin install adlc-solo@obacker-claude-code-plugins

# Install required companion plugins
/plugin install pr-review-toolkit@claude-plugins-official
/plugin install commit-commands@claude-plugins-official

# Install recommended companions
/plugin install claude-md-management@claude-plugins-official
/plugin install context7@claude-plugins-official
/plugin install github@claude-plugins-official

# Install LSP for your stack
/plugin install typescript-lsp@claude-plugins-official  # or pyright-lsp, gopls-lsp, etc.

# Initialize in your project
adlc-init

# Or, for Claude Code cloud sessions (claude.ai/code) — vendors the plugin
# into .claude/ so cloud actually loads it. Commit .claude/ afterwards.
adlc-init --vendor
```

### Local vs cloud

| | Local Claude Code | Cloud (claude.ai/code) |
|---|---|---|
| Repo `.claude/settings.json` hooks | loaded | loaded |
| User-level installed plugins | loaded | **not reliably loaded** |
| What to run | `adlc-init` | `adlc-init --vendor`, then commit `.claude/` |

## Skills

This plugin ships **skills**, not slash commands — there is no `commands/`
directory. Invoke a skill by name, or describe the task and let the `adlc`
router pick one.

| Skill | Invoke as | Description |
|-------|-----------|-------------|
| `adlc` | `/adlc-solo:adlc` | **Smart router** — auto-detects state, routes to the right workflow |
| `build-feature` | `/adlc-solo:build-feature` | Full lifecycle: spec → plan → implement → review → QA → verify |
| `bugfix` | `/adlc-solo:bugfix` | Lightweight fix with root-cause analysis |
| `explore` | `/adlc-solo:explore` | Map existing codebase |
| `plan-milestone` | `/adlc-solo:plan-milestone` | Decompose epic into milestones |
| `plan-slice` | `/adlc-solo:plan-slice` | Break milestone into dev tasks |
| `review-slice` | `/adlc-solo:review-slice` | Post-slice validation |
| `start-session` | `/adlc-solo:start-session` | Resume from where you left off |

## Architecture

```
4 agents:   spec-writer (Opus) → dev-agent (Sonnet, worktree) → qa-spec-checker (Haiku) → qa-adversarial (Sonnet)
8 skills:   adlc (router), build-feature, plan-milestone, plan-slice, review-slice, start-session, bugfix, explore
8 hooks:    protect-spec (PreToolUse: Edit|Write)
            enforce-worktree (PreToolUse: Edit|Write)
            guard-bash-write (PreToolUse: Bash)
            guard-migrations (PreToolUse: Edit|Write|Bash)
            guard-test-lock (PreToolUse: Edit|Write|Bash)
            post-edit-compile-check (PostToolUse: Edit|Write)
            on-agent-stop (SubagentStop)
            save-context (PreCompact + SessionEnd)
7 companions: pr-review-toolkit, commit-commands, claude-md-management, context7, github, security-guidance, LSP
```

## Key Enforcement

A hook only fires for the tools its **matcher** names. A guard registered for
`Edit|Write` does not see a file written through the Bash tool, and vice
versa. The coverage column below states exactly which tools each hook
intercepts — read it before relying on any row.

| What | Hook | Matcher coverage | Level |
|------|------|------------------|-------|
| Spec immutability (Edit/Write path) | `protect-spec.py` PreToolUse | `Edit`, `Write` | Platform (hook denies the call) |
| Spec immutability (Bash path) | `guard-bash-write.py` PreToolUse | `Bash` | Platform (denies parsed write targets only — see Known gaps) |
| Worktree-only code edits (Edit/Write path) | `enforce-worktree.py` PreToolUse | `Edit`, `Write` | Platform (hook denies the call) — opt-in via `.sdlc/.enforce-worktree` |
| Worktree-only code edits (Bash path) | `guard-bash-write.py` PreToolUse | `Bash` | Platform (denies parsed write targets only — see Known gaps) — opt-in |
| Migration needs a rollback | `guard-migrations.py` PreToolUse | `Edit`, `Write`, `Bash` | Platform — opt-in via `.sdlc/.enforce-migrations`, inert unless configured in `verification.yml` |
| Existing tests locked during bugfix | `guard-test-lock.py` PreToolUse | `Edit`, `Write`, `Bash` | Platform — opt-in via `.sdlc/.bugfix-active`, set by the `bugfix` skill |
| Compile check after edits | `post-edit-compile-check.py` PostToolUse | `Edit`, `Write` | Platform (warning only — PostToolUse cannot deny) |
| Context snapshot | `save-context.sh` PreCompact + SessionEnd | all sessions | Platform (automatic) |
| Agent work validation + discovery harvest | `on-agent-stop.sh` SubagentStop | all subagents | Platform (logs and warns; cannot block — the agent already finished) |
| Worktree isolation | `isolation: worktree` in frontmatter | agent spawn | Platform (automatic) |
| Tool restrictions | `tools:` in agent frontmatter | agent spawn | Platform (enforced) |
| Model routing | `model:` in agent frontmatter + spawn-time override | agent spawn | Platform (enforced) |
| Turn limits | `maxTurns:` in agent frontmatter (dev: 35, qa-spec: 20, qa-adv: 25, spec: 30) | agent spawn | Platform (enforced) |
| Two-stage review | qa-spec-checker (Haiku) → qa-adversarial (Sonnet) → pr-review-toolkit | agent spawn | Platform (model in frontmatter) |
| State machine gates | Verification commands at every phase transition | — | Instruction (hard gates) |
| Coverage gate | 85% threshold with max 3 attempts | — | Instruction (dev-agent) |
| Anti-drift rules | Turn 10/15 progress checks, context discipline | — | Instruction (dev-agent) |
| Turn budget mgmt | Agents commit + report DONE_WITH_CONCERNS before hitting limit | — | Instruction (graceful exit) |
| Auto-retry | Orchestrator retries tool-limit/merge-conflict failures (max 2) | — | Instruction (build-feature) |
| Knowledge capture | build-feature Phase 8 updates session-context.md, CAPTURES.md | — | Instruction (checklist) |
| TDD iron law | Agent instructions + anti-rationalization list | — | Instruction (strict) |
| Verification gates | verification.yml commands | — | Command (exit code) |

### Known gaps

The Bash guard parses the command line for write constructs — `>`, `>>`,
heredoc-into-file, `tee`, `sed -i`, `cp`/`mv`, `dd of=`, and `python -c` with
an `open(..., "w")`. It **fails open by design**: a destination it cannot
resolve confidently is allowed, not denied, because a false denial costs more
than the residual gap. Specifically it does not resolve:

- targets built from variables or command substitution (`> $F`, `> $(mktemp)`)
- process substitution (`> >(tee f)`)
- writes performed inside a script the command invokes
- writes by a compiled binary or an interpreter reading from a file

So the Bash path is **narrower than the Edit/Write path**, which sees the
resolved destination directly. Treat it as closing the common bypasses, not as
an airtight boundary.

Run `bash tests/hook-matrix.sh` to see the exact allow/deny decision for every
covered case.

### Opt-in enforcement flags

All three flag-gated guards are off until you create the flag file, and go
inert again when you remove it.

| Flag file | Activates | Extra requirement |
|-----------|-----------|-------------------|
| `.sdlc/.enforce-worktree` | Production code must be edited inside a git worktree (Edit/Write **and** Bash) | none |
| `.sdlc/.enforce-migrations` | A new up-migration needs a matching down artifact | a `migrations:` block in `verification.yml`, otherwise inert |
| `.sdlc/.bugfix-active` | Existing test files are read-only; new test files still allowed | set and cleared by the `bugfix` skill |

The migrations block is optional and is **not** written by `adlc-init`. Add it
yourself when you want the guard:

```yaml
migrations:
  dir: "db/migrations"
  up_suffix: ".up.sql"
  down_suffix: ".down.sql"
```

## Companion Plugin Roles

- **pr-review-toolkit**: 6 specialized code review agents (replaces ADLC's former review-agent)
- **commit-commands**: Tool-restricted git operations (agents can't construct arbitrary git commands)
- **claude-md-management**: CLAUDE.md quality auditing and improvement
- **context7**: Live API/library documentation during development
- **github**: GitHub issues, PRs, Projects integration
- **security-guidance**: Lightweight security reminders on file edits
- **LSP**: Code intelligence (go-to-definition, diagnostics, type checking)

## Requirements

- Claude Code with plugin support
- Git initialized project
- Python 3.x (for hook scripts)
- Bash (for shell hooks)

## Tests

```bash
bash tests/hook-matrix.sh
```

Builds a throwaway git repo with an approved spec and a real worktree, feeds
real hook JSON on stdin to every registered PreToolUse guard, and asserts the
allow/deny decision for 48 cases. Exits non-zero on any mismatch.

## Upgrading

The plugin itself auto-updates if `autoUpdate: true` is set in your marketplace config.
However, **scaffold files in your projects are not auto-updated** — they are generated
once by `adlc-init` and owned by your project after that.

When a new release changes scaffold files, you need to manually apply those changes to
existing projects. See [UPGRADING.md](UPGRADING.md) for per-release instructions.

### Quick reference

| From → To | Action required |
|-----------|-----------------|
| any → v2.1.0 | Add `env` block to `.claude/settings.json` (see UPGRADING.md) |
| v2.1.x → v2.2.0 | Copy `AI Collaboration Principles` section into your project's `CLAUDE.md` (see UPGRADING.md) |
| v2.2.x → v2.3.0 | Re-run `adlc-init` (or `adlc-init --vendor` for cloud); re-check `.claude/settings.json` exists (see UPGRADING.md) |

## License

MIT — oBacker (obacker.com)
