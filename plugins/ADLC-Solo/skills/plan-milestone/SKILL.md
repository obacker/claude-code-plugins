---
name: plan-milestone
description: Plan a milestone — decompose a feature into milestones with scope, dependencies, and effort estimates. No implementation.
argument-hint: Feature or epic description
---

# ADLC Plan Milestone

Create a structured milestone plan from a feature or epic description.

## When to Use

- Feature is too large for a single build-feature cycle
- Need to break an epic into multiple milestones
- Want to plan before committing to implementation

## Process

1. Read domain-context.md and domain-terms.md
2. Read existing .sdlc/milestones/ to understand current project state
3. Clarify scope with user (max 3 questions, one at a time)
4. Decompose into milestones:

For each milestone:
```
### Milestone [ID]: [Title]
- **Scope**: What this milestone delivers (2-3 sentences)
- **ACs (draft)**: Rough acceptance criteria (will be formalized by spec-writer)
- **Dependencies**: Which milestones must complete first
- **Risk flags**: DB migration | auth | financial | PII | breaking API | infra
- **Effort estimate**: S (1-2 days) | M (3-5 days) | L (1-2 weeks)
- **Priority**: Must-have | Should-have | Nice-to-have
```

5. Identify the critical path: which milestones block others?
6. Suggest implementation order based on dependencies and priority
7. Present plan to user

## Output

Write to `.sdlc/milestone-plan-[EPIC-ID].md`

## Rules

- Max 5-7 milestones per epic. If more: the epic needs to be split first.
- Each milestone must be independently shippable (delivers user value on its own)
- Don't estimate effort for unknowns — flag them as "needs spike" instead
- Draft ACs are rough — spec-writer will formalize them during build-feature

## Next Steps

After user approves milestone plan:
- For each milestone in order: run `/adlc:build-feature [milestone description]`
- Or: run `/adlc:plan-slice [milestone-id]` for more detailed task breakdown first
