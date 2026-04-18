# {{PROJECT_NAME}}

## Stack
{{STACK}} (e.g., TypeScript / Next.js / PostgreSQL / Vercel)

## Commands
- Build: `{{BUILD_CMD}}`
- Lint: `{{LINT_CMD}}`
- Test: `{{TEST_CMD}}`
- Dev server: `{{DEV_CMD}}`

## ADLC
This project uses ADLC v13 for structured feature development.

- Domain context: domain-context.md
- Domain terms: domain-terms.md
- Verification gates: verification.yml
- Feature tracking: .sdlc/milestones/[ID]/feature-registry.json
- Agent logs: .sdlc/agent-log.txt

### Key Rules
1. **Spec first**: No implementation without approved BDD acceptance criteria.
2. **Immutable spec**: After user approval, ACs cannot be modified by any agent. Protected by hook.
3. **TDD iron law**: No production code without a failing test first. No exceptions.
4. **Isolation**: Each dev task runs in its own worktree. Enforced by hook when `.sdlc/.enforce-worktree` is active.
5. **Delegate, don't implement**: Orchestrator investigates and plans. Dev-agent implements. Never edit production code directly.
6. **Review + QA mandatory**: Every slice and bugfix needs spec compliance check AND QA validation.
7. **Domain terms**: Use exact terminology from domain-terms.md. Never invent synonyms.
8. **Verification gates**: All commands in verification.yml must pass before claiming done.
9. **Knowledge capture**: Update domain-context.md, domain-terms.md after implementation. Knowledge that isn't written down is lost.

### AI Collaboration Principles

The AI is the hands; the human is the architect. Move fast, but never faster than the human can verify.

1. **Think before coding** — State assumptions out loud. If intent is ambiguous, stop and ask; never guess. When multiple approaches exist, surface the trade-offs — do not silently pick one.
2. **Simplicity first** — Write the minimum code that solves the stated problem. No extra features, config knobs, or abstractions that weren't requested. 50 lines beats 200 lines if both work.
3. **Surgical changes** — Only touch code that must change. Do not reformat, re-comment, or "improve" unrelated code. Do not delete legacy code unless asked. Clean up only what you just introduced.
4. **Define success criteria** — Work in a loop against explicit, user-agreed criteria. Do not declare done until verification gates pass and the criteria are met.

### Session Discipline

When completing a task, ALWAYS update context files (CLAUDE.md, domain-context.md, ROADMAP.md, etc.) before declaring the session closed. Never skip documentation updates.

When asked to execute a plan, EXECUTE it immediately. Do not spend the entire session reading files and producing a plan unless explicitly asked to only plan. If a plan is already approved, begin implementation without re-analysis.

Before you start: re-read the Session Discipline and Key Rules sections of CLAUDE.md. Confirm you understand the required phases. Do not skip any phase. Do not declare the session complete until all context files are updated and committed.

### ADLC Process Compliance

Follow the ADLC workflow phases in order (spec → TDD → implement → review → QA). Do not skip phases or jump ahead without explicit user approval. If a process is defined, follow it before writing code.

### Parallel Agent Isolation

When using parallel sub-agents or worktrees, ensure each agent works on isolated files/branches. Never let multiple agents share the same working tree or branch. Verify no overlapping file edits before committing.

When using parallel agents: assign each agent a specific set of files or packages. No two agents should edit the same file. Each agent must work on its own branch or verify no conflicts before committing. After all agents complete, the orchestrator will review and merge.

### Language-Specific Conventions

{{Add project-specific conventions here. Examples:}}
- For Go backend: always use json struct tags on exported fields. Before writing Go structs, check that all exported fields have json tags.
- For frontend: never remove CSS classes without verifying they're unused across all files.
- For Tailwind v4: use proper @import syntax — do not use @tailwind directives.
- Before any Docker build, confirm the target platform is linux/amd64.

### Deployment Procedures

{{Add project-specific deployment procedures here. Examples:}}
- Always use the documented promote/deploy procedure (not manual deploy scripts).
- Build Docker images for linux/amd64.
- Use Cloud Build 2nd gen triggers (not 1st gen).
- Never use os.Exit(1) in health checks — return errors gracefully.

### Project-Level Hooks

This project has `.claude/settings.json` with hooks that run in ALL Claude Code sessions (not just ADLC plugin sessions). These coexist with the ADLC plugin hooks:

- **PostToolUse (Edit|Write)**: Runs compile/type checks after every source file edit
- **PreCompact**: Runs build validation before context window compaction

To customize: edit `.claude/settings.json` with your project's build/lint commands.

### Performance Configuration

Token optimization env vars are pre-configured in `.claude/settings.json` (set by `adlc-init`):
- `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=75` — compact at 75% of context window
- `CLAUDE_CODE_MAX_OUTPUT_TOKENS=16000` — cap output token usage

These merge with global `~/.claude/settings.json` env vars (deep-merge, no replacement).

After compaction: always read `.sdlc/context-snapshot.md` first.

### Workflow Commands
- `/adlc:build-feature [description]` — Full lifecycle (spec → plan → implement → review → QA → verify)
- `/adlc:bugfix [description]` — Lightweight bug fix with root-cause analysis
- `/adlc:explore` — Map existing codebase
- `/adlc:plan-milestone [description]` — Plan milestones for an epic
- `/adlc:plan-slice [milestone-id]` — Break milestone into dev tasks
- `/adlc:review-slice [milestone-id slice-N]` — Post-slice validation
- `/adlc:start-session` — Resume work from where you left off
