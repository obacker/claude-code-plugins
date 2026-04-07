# {{PROJECT_NAME}}

## Stack
{{STACK}} (e.g., TypeScript / Next.js / PostgreSQL / Vercel)

## Commands
- Build: `{{BUILD_CMD}}`
- Lint: `{{LINT_CMD}}`
- Test: `{{TEST_CMD}}`
- Dev server: `{{DEV_CMD}}`

## ADLC
This project uses ADLC v12 for structured feature development.

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

### Workflow Commands
- `/adlc:build-feature [description]` — Full lifecycle (spec → plan → implement → review → QA → verify)
- `/adlc:bugfix [description]` — Lightweight bug fix with root-cause analysis
- `/adlc:explore` — Map existing codebase
- `/adlc:plan-milestone [description]` — Plan milestones for an epic
- `/adlc:plan-slice [milestone-id]` — Break milestone into dev tasks
- `/adlc:review-slice [milestone-id slice-N]` — Post-slice validation
- `/adlc:start-session` — Resume work from where you left off
