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

Each task must be:
- **Atomic**: completable in 30-90 minutes by a single dev-agent
- **Specific**: exact file paths to create/modify, exact ACs covered
- **Testable**: expected test names listed, verification command specified
- **Independent where possible**: tasks that don't share files can parallelize

For each task, specify:
```
Task [N]: [Title]
- Files: [exact paths to create or modify]
- ACs covered: [AC IDs]
- Test names: Test_[Feature]_AC[N]_[Behavior]
- Dependencies: [task IDs this depends on, or "none"]
- Parallel: [yes/no — can run simultaneously with other tasks in same slice]
- Estimated complexity: simple (≤2 files) | moderate (3-5 files) | complex (6+ files)
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
- A task that touches 6+ files is probably two tasks — split it
