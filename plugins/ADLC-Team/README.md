# adlc-team v7 — Agent-Driven Lifecycle (Team Edition)

3 role-based agents, 10 skills, platform-level enforcement. Built for teams of 3-8 people working on the same repo with GitHub Projects.

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
3 agents:   ba-agent (Sonnet) → dev-agent (Sonnet, worktree) → qa-agent (Sonnet, worktree)
10 skills:  ba-start, ba-write-spec, dev-start, dev-split-tasks, dev-implement, dev-bugfix, qa-start, qa-test-adversarial, shared-explore, shared-write-ui-tests
4 hooks:    protect-spec (PreToolUse) + enforce-worktree (PreToolUse) + on-agent-stop (SubagentStop) + save-context (PreCompact/SessionEnd)
5 companions: pr-review-toolkit, commit-commands, claude-md-management, context7, github
```

## Skills by Role

### BA — Business Analyst (2 skills)

| Skill | Trigger | What it does |
|---|---|---|
| `ba-start` | "start working as BA" | Load state, check GitHub Issues needing specs |
| `ba-write-spec` | Describe a feature | Clarify → structure options → BDD spec with self-review → approval |

### DEV — Developer (4 skills)

| Skill | Trigger | What it does |
|---|---|---|
| `dev-start` | "start working as DEV" | Detect repo mode (A/B/C/D), surface specs and tasks to pick up |
| `dev-split-tasks` | "break [FEAT-ID] into tasks" | Approved spec → small atomic tasks (1 AC, max 3 files, inline context) in slices |
| `dev-implement` | "start implementing" | Create GitHub Issues, plan parallel execution, spawn dev-agents, code review, track progress |
| `dev-bugfix` | "fix bug" | 6-step fast-track: reproduce → root cause → test → fix → verify → document |

### QA — Quality Assurance (2 skills)

| Skill | Trigger | What it does |
|---|---|---|
| `qa-start` | "start working as QA" | Check features ready for QA, plan exploratory tests |
| `qa-test-adversarial` | "adversarial tests" | Edge cases, security, boundary attacks → findings report |

### Shared (2 skills)

| Skill | Trigger | What it does |
|---|---|---|
| `shared-explore` | "explore codebase" | Map stack, architecture, domain, tests, code health |
| `shared-write-ui-tests` | "UI tests for [FEAT-ID]" | Playwright tests from BDD — DEV for happy path, QA for edge cases |

## Enforcement Levels

| What | How | Level |
|------|-----|-------|
| Spec immutability | `protect-spec.py` PreToolUse hook | **Platform** (denies the action) |
| Worktree-only code edits | `enforce-worktree.py` PreToolUse hook | **Platform** (denies the action) |
| Worktree isolation | `isolation: worktree` in agent frontmatter | **Platform** (automatic) |
| Tool restrictions | `tools:` in agent frontmatter | **Platform** (enforced) |
| Model routing | `model:` in agent frontmatter | **Platform** (enforced) |
| Turn limits | `maxTurns:` in agent frontmatter | **Platform** (enforced) |
| Turn budget mgmt | Agents commit + report DONE_WITH_CONCERNS before hitting limit | **Instruction** (graceful exit) |
| Task sizing | DEV writes 1 AC/task, max 3 files, inline context — fits dev-agent turn budget | **Instruction** (DEV rules) |
| Knowledge harvesting | `on-agent-stop.sh` SubagentStop hook | **Platform** (automatic) |
| Mandatory agent spawn | Skills + enforce-worktree hook | **Platform + Instruction** (hook blocks lazy path) |
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
