---
name: plan-slice
description: Break a milestone into implementation slices and tasks. Use after spec is approved to plan the dev work.
argument-hint: Milestone ID (e.g., "M001")
---

# ADLC Plan Slice

Decompose an approved milestone spec into implementation slices and atomic dev tasks.

## Prerequisites

- milestone-spec.md exists and is approved (spec_approved_at is set)
- feature-registry.json exists with AC definitions

## Process

1. Read .sdlc/milestones/[MILESTONE-ID]/milestone-spec.md
2. Read .sdlc/milestones/[MILESTONE-ID]/feature-registry.json
3. Read domain-context.md for architectural context
4. Read verification.yml for available test/build commands
5. Map the codebase: which existing files relate to each AC?

## Task Decomposition Rules

**Dev-agent has a 35-turn budget.** Every task must fit within this. Oversize tasks cause DONE_WITH_CONCERNS cascades and re-spawns — avoid by splitting aggressively.

Each task must be:
- **Small enough for 35 turns**: 1-2 ACs, max 3 files changed. A TDD cycle (read → failing test → implement → green → coverage check) takes ~10-15 turns per file.
- **Specific**: exact file paths to create/modify, exact ACs covered
- **Testable**: expected test names listed, verification command specified
- **Independent where possible**: tasks that don't share files can parallelize

**Sizing guide (based on 35-turn budget):**

| Complexity | Files | ACs | Estimated Turns | Fits in Budget? |
|-----------|-------|-----|----------------|-----------------|
| Simple | 1-2 | 1 | 10-15 | Yes — use `model: haiku` |
| Moderate | 2-3 | 1-2 | 15-25 | Yes — use `model: sonnet` |
| Large | 4-5 | 2-3 | 25-35 | Tight — split if possible |
| Too large | 6+ | 3+ | 35+ | **Must split** — will exceed budget |

If a task touches 4+ files: split into two tasks unless the files are tightly coupled (e.g., model + test for same entity).

For each task, specify:
```
Task [N]: [Title]
- Files: [exact paths to create or modify — max 3 recommended]
- ACs covered: [AC IDs — max 2 per task]
- Test names: Test_[Feature]_AC[N]_[Behavior]
- Dependencies: [task IDs this depends on, or "none"]
- Parallel: [yes/no — can run simultaneously with other tasks in same slice]
- Estimated complexity: simple (1-2 files) | moderate (2-3 files) | large (4+ files, consider splitting)
- Model recommendation: haiku (simple) | sonnet (moderate) | opus (complex/architectural)
```

## Slice Grouping

Group tasks into slices (each slice = half-day of work):
- Slice contains 2-4 tasks
- Independent tasks within a slice are marked for parallel execution
- Each slice should deliver a testable increment
- Slice order respects task dependencies

## Output

Write to `.sdlc/milestones/[MILESTONE-ID]/slice-plan.md`:

```markdown
# Slice Plan: [Milestone Title]

## Slice 1: [Description]
Estimated: [X hours]

### Task 1.1: [Title]
- Files: src/models/user.ts (create), src/models/user.test.ts (create)
- ACs: AC1, AC2
- Tests: Test_Auth_AC1_ValidLogin, Test_Auth_AC2_InvalidPassword
- Dependencies: none
- Parallel: yes
- Model: sonnet

### Task 1.2: [Title]
...

## Slice 2: [Description]
Depends on: Slice 1
...
```

Present to user for approval before implementation begins.

## Rules

- Never create tasks that modify milestone-spec.md
- If an AC cannot be decomposed into tasks: flag it — the AC may be too vague
- If task scope overlaps with another task: merge or redefine boundaries
- A task that touches 4+ files should be split — dev-agent has a 35-turn budget
- If a single AC requires 4+ files: split into "create models/types" + "wire up integration" tasks
