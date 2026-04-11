# ADLC v13 — Agent-Driven Lifecycle

Structured feature development for Claude Code: BDD specs, TDD implementation, automated review, and verification gates.

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
```

## Commands

| Command | Description |
|---------|-------------|
| `/adlc` | **Smart router** — auto-detects state, routes to right workflow |
| `/adlc:build-feature [description]` | Full lifecycle: spec → plan → implement → review → QA → verify |
| `/adlc:bugfix [description]` | Lightweight fix with root-cause analysis |
| `/adlc:explore` | Map existing codebase |
| `/adlc:plan-milestone [description]` | Decompose epic into milestones |
| `/adlc:plan-slice [milestone-id]` | Break milestone into dev tasks |
| `/adlc:review-slice [id slice-N]` | Post-slice validation |
| `/adlc:start-session` | Resume from where you left off |

## Architecture

```
4 agents:   spec-writer (Opus) → dev-agent (Sonnet, worktree) → qa-spec-checker (Haiku) → qa-adversarial (Sonnet)
8 skills:   adlc (router), build-feature, plan-milestone, plan-slice, review-slice, start-session, bugfix, explore
5 hooks:    protect-spec (PreToolUse), enforce-worktree (PreToolUse), post-edit-compile-check (PostToolUse), on-agent-stop (SubagentStop), save-context (PreCompact)
7 companions: pr-review-toolkit, commit-commands, claude-md-management, context7, github, security-guidance, LSP
```

## Key Enforcement

| What | How | Level |
|------|-----|-------|
| Spec immutability | `protect-spec.py` PreToolUse hook | Platform (hook blocks the action) |
| Worktree-only code edits | `enforce-worktree.py` PreToolUse hook — blocks on ALL branches | Platform (hook blocks the action) |
| Compile check after edits | `post-edit-compile-check.py` PostToolUse hook | Platform (warning on failure) |
| Worktree isolation | `isolation: worktree` in frontmatter | Platform (automatic) |
| Tool restrictions | `tools:` in agent frontmatter | Platform (enforced) |
| Model routing | `model:` in agent frontmatter + spawn-time override | Platform (enforced) |
| Turn limits | `maxTurns:` in agent frontmatter (dev: 35, qa-spec: 20, qa-adv: 25, spec: 30) | Platform (enforced) |
| State machine gates | Verification commands at every phase transition | Instruction (hard gates) |
| Coverage gate | 85% threshold with max 3 attempts | Instruction (dev-agent) |
| Anti-drift rules | Turn 10/15 progress checks, context discipline | Instruction (dev-agent) |
| Turn budget mgmt | Agents commit + report DONE_WITH_CONCERNS before hitting limit | Instruction (graceful exit) |
| Auto-retry | Orchestrator retries tool-limit/merge-conflict failures (max 2) | Instruction (build-feature) |
| Knowledge capture | build-feature Phase 8 updates session-context.md, CAPTURES.md | Instruction (checklist) |
| TDD iron law | Agent instructions + anti-rationalization list | Instruction (strict) |
| Two-stage review | qa-spec-checker (Haiku, platform) → qa-adversarial (Sonnet, platform) → code quality (pr-review-toolkit) | Platform (model in frontmatter) |
| Verification gates | verification.yml commands | Command (exit code) |

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

## License

MIT — oBacker (obacker.com)
