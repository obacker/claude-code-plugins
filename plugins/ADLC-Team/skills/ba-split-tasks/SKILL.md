---
name: ba-split-tasks
description: "Break an approved spec into atomic dev tasks. Trigger: 'break [FEAT-ID] into tasks', 'create tasks for', 'task breakdown for'. Guard: spec must be approved."
---

<context>
You transform an approved BDD spec into atomic implementation tasks that dev-agents can execute independently via TDD. Each task must be completable in 30-90 minutes.
</context>

<instructions>

## Step 0 — Guard: verify spec is approved

```bash
# Check registry for approval
cat .sdlc/specs/[FEAT-ID]-registry.json | python3 -c "
import sys, json
data = json.load(sys.stdin)
approved = data.get('spec_approved_at')
if not approved:
    print('BLOCKED: Spec not approved yet. Get BA to approve first.')
    sys.exit(1)
print(f'Spec approved at {approved}')
"
```

If not approved, stop immediately. Do not proceed.

## Step 1 — Read spec and context

- `.sdlc/specs/[FEAT-ID]-*-spec.md` — the approved spec
- `.sdlc/domain-terms.md` — terminology
- `CLAUDE.md` — project structure and stack
- `.sdlc/verification.yml` — what gates exist

## Step 2 — Decompose into tasks

Dev-agents are subagents with **limited turns (maxTurns: 40)**. A task that's too large will hit the turn limit and lose work. Err on the side of too small — two trivial tasks are better than one that times out.

For each task, define:
- **Title**: `[FEAT-ID]-T[NNN]: [action verb] [what]`
- **ACs covered**: 1 AC per task (2 only if trivially related)
- **Files to touch**: exact file paths (existing or new) — max 3 files
- **Dependencies**: which tasks must complete first
- **Complexity**: simple (1 TDD cycle) / moderate (2 TDD cycles)
- **Test name**: `Test_[Feature]_AC[N]_[Behavior]` — specify it, don't let dev-agent guess
- **Inline context**: paste the relevant AC text, code snippets, and expected behavior directly in the task. Dev-agent can't ask questions — everything it needs must be in the task file.

Sizing rules:
- **1 AC per task** — split unless ACs are trivially coupled (e.g., create + read of same entity)
- **Max 3 files changed** — if 4+ files, split by file group
- **Max 2 TDD cycles** — if you estimate 3+ RED-GREEN-REFACTOR cycles, split
- If two tasks modify the same file, note the overlap and consider merging or sequencing
- Flag any task that requires DB migration or infrastructure changes
- Complex tasks (6+ files, architectural decisions) → split into a "scaffold" task + "logic" task

## Step 3 — Group into slices

Group tasks into half-day slices (2-4 tasks per slice):
- Slice 1: foundation tasks (models, types, basic CRUD)
- Slice 2: business logic tasks
- Slice 3: integration and edge cases

Within each slice, mark which tasks can run in parallel.

## Step 4 — Write task files

Output to `.sdlc/tasks/[FEAT-ID]/task-[NNN].md`:

```markdown
# [FEAT-ID]-T[NNN]: [Title]

## Acceptance Criteria (paste full text — don't reference spec)
**AC-[N]: [title]**
**Given** [precondition with concrete values]
**When** [action with specific input]
**Then** [expected outcome with measurable result]

## Implementation scope
**Files to create:**
- [path] — [purpose]

**Files to modify:**
- [path] — [what changes and why]

## Test-first approach
Write this test first (RED):
- `Test_[Feature]_AC[N]_[Behavior]` — [what it asserts, expected input/output]

## Context (paste relevant code snippets)
```
[existing function signatures, types, or patterns the dev-agent needs to know]
```

## Dependencies
- Depends on: [task IDs or "none"]
- Blocks: [task IDs or "none"]

## Complexity: [simple (1 TDD cycle) | moderate (2 TDD cycles)]

## Verification
Run after implementation:
- post_task gates from verification.yml
```

Also create slice plan at `.sdlc/tasks/[FEAT-ID]/slice-plan.md`:

```markdown
# [FEAT-ID] Slice Plan

## Slice 1: [theme]
| Task | Complexity | Parallel? | Depends on |
|---|---|---|---|
| T001 | simple | yes | none |
| T002 | moderate | yes | none |
| T003 | moderate | no | T001 |

## Slice 2: [theme]
...
```

## Step 5 — Present for approval

Show the slice plan to the user. Wait for approval before creating GitHub Issues.

On approval:
```bash
# Create task issues
for each task:
  gh issue create --title "[FEAT-ID]-T[NNN]: [title]" \
    --body-file .sdlc/tasks/[FEAT-ID]/task-[NNN].md \
    --label "adlc:task,adlc:ready" \
    --project [PROJECT_NUMBER]

# Update spec issue
gh issue comment [SPEC_ISSUE] --body "## BA: Task breakdown complete — [FEAT-ID]
**Tasks:** [count] tasks in [count] slices
**Ready for DEV:** Pick up via dev-start"

gh issue edit [SPEC_ISSUE] --remove-label "adlc:spec-approved" --add-label "adlc:tasks-ready"
```

</instructions>

<documents>
- `.sdlc/specs/[FEAT-ID]-*-spec.md`
- `.sdlc/specs/[FEAT-ID]-registry.json`
- `.sdlc/domain-terms.md`
- `.sdlc/verification.yml`
</documents>
