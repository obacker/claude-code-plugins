# adlc-team v7.2 — Agent-Driven Lifecycle (Team Edition)

3 role-based agents, 9 active skills + 3 deprecated redirects, platform-level enforcement. Built for teams of 3-8 people working on the same repo with GitHub Projects.

## What changed in v7.2 (from v7.1) — RAM + hang + token fixes

Target reductions (see `Misc/ADLC-Team-Optimization-Plan.md`): max hang 20m→10m, peak RAM ~45% down, dev-implement skill ~60% smaller in hot path, sonnet/haiku ratio 95/5 → 60/40, PreToolUse fork count 2→1.

**Hang & timeout**
- `maxTurns` tightened: dev-agent 40→30, qa-agent 30→25, ba-agent 30→25 — forces graceful `DONE_WITH_CONCERNS` instead of stalling at the ceiling
- Mandatory 10-minute wall-clock timeout on every agent spawn, with a HUNG recovery path (force-remove worktree, offer split / switch-to-haiku / skip-and-escalate)
- Turn-status logging at turns 10/20/25 so the orchestrator can see progress

**RAM**
- Hard cap of **2 parallel dev-agents** (queue any extras)
- Task files passed to dev-agent by **file path**, not pasted content — single source of truth, no duplication across parallel spawns
- PR review runs **sequentially** (code-reviewer → pr-test-analyzer), analyzer references code-reviewer output
- SubagentStop KNOWLEDGE harvest forked to background; hook returns immediately

**Token / cost**
- `dev-implement` split into a slim orchestrator (~80 lines) + `references/github-ops.md` + `references/spawn-patterns.md` — references only loaded when the specific step runs
- `_shared/load-sdlc-context.md` replaces duplicated "read these 4 files" blocks across DEV skills
- `ba-write-spec` and `shared-explore` use progressive disclosure — full templates live under `references/`
- **Mandatory Haiku routing** for simple / mechanical tasks (renames, stubs, formatting, config bumps, single-line changes)
- **Advisor escalation pattern** — Orchestrator and agents all default to Sonnet. On architectural decisions, multi-file churn, spec ambiguity, or retry-failed verification, agents exit `DONE_WITH_CONCERNS` tagged `needs-orchestrator-advisor`; the orchestrator then calls its built-in `advisor` tool (Opus-backed) before respawning with tightened constraints. (Previous plan draft used a non-existent `advisor:` YAML key — corrected to an instruction-level pattern that matches Claude Code's supported frontmatter.)
- New `dev-cost-report` skill for weekly per-feature token + hang audit

**Hooks**
- 2 Python PreToolUse hooks (`protect-spec.py` + `enforce-worktree.py`) replaced by a single bash wrapper (`pretooluse-guard.sh`) with a fast-path for ADLC artifacts — ~50% fork overhead gone. Old `.py` scripts kept as `.bak` for 30 days.
- New PostToolUse `compile-check.sh` hook — Go vet / tsc / python syntax check surfaces compile errors within the current TDD cycle. Advisory (never blocks).
- Project-level hook scaffold at `scaffold/.claude/hooks-project-example.json` for repo-specific lint/typecheck.

### Upgrading from v7.1 to v7.2

See `UPGRADING.md`. No changes required to `.sdlc/` contents, feature registries, or existing specs.

## What changed in v7.1 (from v7)

- **~40% token reduction** — Spawn prompts stripped to task-specific context only; TDD rules, verification gates, commit conventions, and report formats are no longer duplicated from agent definitions into every spawn call
- **3 start skills → 1 smart-start** — `ba-start`, `dev-start`, `qa-start` merged into `smart-start` which loads shared context once and branches by role. Old skills remain as deprecated redirects for backward compatibility.
- **Removed redundant "MUST NOT" sections** — Platform hooks (enforce-worktree, protect-spec) already enforce these constraints; instruction-level repetition removed from 4 skills
- **Leaner PR review spawn** — `dev-implement` Step 7 review spawn prompts reduced from ~20 lines to 2 lines each; pr-review-toolkit agents use their own built-in checklists

### Upgrading from v7.0 to v7.1

1. Update the plugin: `/plugin update adlc-team@obacker-claude-code-plugins`
2. If your project's `CLAUDE.md` references `ba-start`, `dev-start`, or `qa-start`, replace them with `smart-start`
3. Re-run `adlc-init --force` to update scaffold files (or manually edit `CLAUDE.md` in your project)
4. No changes needed to `.sdlc/` files, verification.yml, or hooks — all backward compatible
5. Old `/ba-start`, `/dev-start`, `/qa-start` commands still work (they redirect to smart-start)

## What changed in v7 (from v6)

- **Task splitting moved to DEV** — `ba-split-tasks` → `dev-split-tasks` (BA: 3→2 skills, DEV: 3→4 skills). DEV now owns the full implementation lifecycle: split → implement → review.
- **Code review integrated** — `dev-implement` Step 7 now creates PR and invokes `pr-review-toolkit:review-pr` before QA handoff
- **ba-agent simplified** — BA focuses solely on specs and domain terms, no longer writes task files

## What changed in v6 (from v5)

- **18 skills → 10** — dropped skills that overlap with companion plugins
- **3 agents with frontmatter enforcement** — tool restrictions, model routing, worktree isolation, turn limits at platform level
- **protect-spec hook** — PreToolUse hook denies edits to approved specs (was instruction-only in v5)
- **Auto-harvest knowledge** — on-agent-stop hook auto-extracts discoveries from progress files to KNOWLEDGE.md
- **Self-review at every role** — BA self-reviews spec quality, DEV self-tests via TDD, QA focuses on edge cases
- **Turn budget management** — all 3 agents commit partial work and report DONE_WITH_CONCERNS before hitting turn limit; orchestrator auto-continues
- **Task sizing for agents** — DEV writes tasks small enough for dev-agent's 40-turn budget: 1 AC/task, max 3 files, all context inline
- **Dropped:** steering.md, file locks, captures, code-review-council, context-engineer, knowledge-keeper skill, domain-terms-builder, failure-semantics-designer, responsibility-mapper, eval-suite-builder
- **Delegated to companions:** code review (pr-review-toolkit), git operations (commit-commands), context files (claude-md-management)

## Install

```bash
# Install ADLC Team
/plugin install adlc-team@obacker-claude-code-plugins

# Required companions
/plugin install pr-review-toolkit@claude-plugins-official
/plugin install commit-commands@claude-plugins-official

# Recommended
/plugin install claude-md-management@claude-plugins-official
/plugin install context7@claude-plugins-official
/plugin install github@claude-plugins-official

# LSP for your stack
/plugin install typescript-lsp@claude-plugins-official  # or pyright-lsp, gopls-lsp

# Initialize project
adlc-init
```

## Architecture

```
orchestrator: Sonnet (main conversation) — with access to the `advisor` tool for Opus-backed second opinions
3 agents:    ba-agent (Sonnet) → dev-agent (Sonnet/Haiku, worktree) → qa-agent (Sonnet, worktree)
             Agents surface architectural / ambiguity decisions; orchestrator calls `advisor` on their behalf.
9 skills:   smart-start, ba-write-spec, dev-split-tasks, dev-implement, dev-bugfix, dev-cost-report, qa-test-adversarial, shared-explore, shared-write-ui-tests
3 deprecated: ba-start, dev-start, qa-start (redirect to smart-start)
4 hooks:    pretooluse-guard (PreToolUse, bash) + compile-check (PostToolUse) + on-agent-stop (SubagentStop, async harvest) + save-context (PreCompact/SessionEnd)
5 companions: pr-review-toolkit, commit-commands, claude-md-management, context7, github
```

## Skills

### Session Start (1 skill, replaces 3)

| Skill | Trigger | What it does |
|---|---|---|
| `smart-start` | "start working", "BA/DEV/QA session" | Auto-detect role, load shared context once, show role-specific dashboard with actionable options |

### BA — Business Analyst (1 skill)

| Skill | Trigger | What it does |
|---|---|---|
| `ba-write-spec` | Describe a feature | Clarify → structure options → BDD spec with self-review → approval |

### DEV — Developer (4 skills)

| Skill | Trigger | What it does |
|---|---|---|
| `dev-split-tasks` | "break [FEAT-ID] into tasks" | Approved spec → small atomic tasks (1 AC, max 3 files, inline context) in slices |
| `dev-implement` | "start implementing" | Create GitHub Issues, plan parallel execution (max 2), spawn dev-agents with timeouts, sequential code review, track progress |
| `dev-bugfix` | "fix bug" | Fast-track: investigate → spawn dev-agent → spawn qa-agent → document |
| `dev-cost-report` | "cost report", "weekly cost" | Weekly audit of token burn, sonnet/haiku ratio, hang events, sessions over budget |

### QA — Quality Assurance (1 skill)

| Skill | Trigger | What it does |
|---|---|---|
| `qa-test-adversarial` | "adversarial tests" | Plan attack vectors → spawn qa-agent → findings report |

### Shared (2 skills)

| Skill | Trigger | What it does |
|---|---|---|
| `shared-explore` | "explore codebase" | Map stack, architecture, domain, tests, code health |
| `shared-write-ui-tests` | "UI tests for [FEAT-ID]" | Playwright tests from BDD — DEV for happy path, QA for edge cases |

## Enforcement Levels

| What | How | Level |
|------|-----|-------|
| Spec immutability | `pretooluse-guard.sh` PreToolUse hook (bash, replaces Python) | **Platform** (denies the action) |
| Worktree-only code edits | `pretooluse-guard.sh` PreToolUse hook | **Platform** (denies the action) |
| Spawn timeout & HUNG recovery | 10-min wall-clock per agent (instructed in `spawn-patterns.md`) | **Instruction** |
| Parallel agent cap | Max 2 dev-agents simultaneous | **Instruction** (dev-implement) |
| Compile check | `compile-check.sh` PostToolUse hook | **Platform** (advisory) |
| Worktree isolation | `isolation: worktree` in agent frontmatter | **Platform** (automatic) |
| Tool restrictions | `tools:` in agent frontmatter | **Platform** (enforced) |
| Model routing | `model:` in agent frontmatter | **Platform** (enforced) |
| Turn limits | `maxTurns:` in agent frontmatter | **Platform** (enforced) |
| Turn budget mgmt | Agents commit + report DONE_WITH_CONCERNS before hitting limit | **Instruction** (graceful exit) |
| Task sizing | DEV writes 1 AC/task, max 3 files, inline context — fits dev-agent turn budget | **Instruction** (DEV rules) |
| Knowledge harvesting | `on-agent-stop.sh` SubagentStop hook | **Platform** (automatic) |
| Mandatory agent spawn | Skills + pretooluse-guard hook | **Platform + Instruction** (hook blocks lazy path) |
| TDD iron law | dev-agent instructions | **Instruction** (strict) |
| BA self-review | ba-write-spec checklist | **Instruction** (self-check) |
| Model cost routing | Skill instructions (haiku/sonnet/opus table) | **Instruction** (guidance) |
| Verification gates | verification.yml commands | **Command** (exit code) |
| Spec approval guard | dev-split-tasks Step 0 check | **Command** (exit code) |

## Workflow

```
Feature request
    │
    ▼
BA: ba-write-spec ──→ BDD spec with self-review ──→ User approves
    │                                                       │
    │                                                [spec locked by hook]
    ▼
DEV: dev-split-tasks ──→ Task breakdown + slice plan ──→ User approves
    │
    ▼
DEV: dev-implement ──→ GitHub Issues created ──→ dev-agents spawned (worktree)
    │                                                  │
    │                                      TDD: RED → GREEN → REFACTOR
    │                                      Self-test: verification.yml
    ▼
DEV: tasks complete ──→ pr-review-toolkit (companion) ──→ Code review
    │
    ▼
QA: qa-test-adversarial ──→ Edge cases, security ──→ QA report
    │
    ▼
Merge ──→ Done
```

## File Ownership

| Path | Owner | Readers |
|---|---|---|
| `.sdlc/specs/*` | BA | DEV, QA |
| `.sdlc/tasks/*/` | DEV | DEV |
| `.sdlc/reviews/*` | QA | DEV |
| `.sdlc/_active/*` | DEV | DEV |
| `.sdlc/domain-terms.md` | BA | Everyone |
| `.sdlc/domain-context.md` | BA | Everyone |
| `.sdlc/KNOWLEDGE.md` | All (auto-harvested) | All |
| `.sdlc/verification.yml` | DEV | All agents |

## GitHub Labels

| Label | Meaning |
|---|---|
| `adlc:needs-spec` | Feature needs BA spec work |
| `adlc:spec-draft` | Spec written, awaiting approval |
| `adlc:spec-approved` | Spec approved, ready for task breakdown |
| `adlc:tasks-ready` | Tasks created, ready for DEV |
| `adlc:task` | Individual dev task |
| `adlc:ready` | Task ready for pickup |
| `adlc:in-progress` | Task being worked on |
| `adlc:done` | Task completed |
| `adlc:blocked` | Task blocked |
| `adlc:ready-for-qa` | All tasks done, ready for QA |
| `adlc:qa-passed` | QA approved |
| `adlc:qa-failed` | QA found critical issues |

## Requirements

- Claude Code with plugin support
- Git initialized project
- Python 3.x (for protect-spec.py hook)
- Bash (for shell hooks)
- `gh` CLI (for GitHub Issues/Projects integration)

## License

MIT — oBacker (obacker.com)
