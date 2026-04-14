---
name: ba-write-spec
description: "Write BDD specification with acceptance criteria for a feature. Includes self-review checklist. Trigger: feature description, 'write spec for', 'spec for issue #N', or when BA picks a feature to specify."
---

<context>
You produce BDD specifications that DEV can implement via TDD and QA can validate. Quality of the spec determines quality of everything downstream. Self-review is mandatory before presenting to the user.
</context>

<instructions>

## Step 1 — Gather context

Read:
- `.sdlc/domain-context.md` — business domain
- `.sdlc/domain-terms.md` — use EXACT terms, never invent synonyms
- `.sdlc/specs/` — existing specs for consistency
- The GitHub Issue if one exists: `gh issue view [N] --json title,body,comments,labels`

## Step 2 — Clarify (max 5 questions, one at a time)

Ask clarifying questions to fill gaps. Focus on:
- Who is the user/actor?
- What's the expected behavior for edge cases?
- Are there existing constraints or dependencies?
- What's the scope boundary — what is explicitly OUT of scope?

Stop asking when you have enough to write unambiguous ACs.

## Step 3 — Propose structure

Present 2-3 structural approaches with trade-offs before writing the full spec. Example:
- "Approach A: Single endpoint with query params — simpler, but harder to cache"
- "Approach B: Separate endpoints per resource — more REST-ful, easier caching"

Wait for user to pick or blend approaches.

## Step 4 — Write spec

Output to `.sdlc/specs/[FEAT-ID]-[slug]-spec.md`:

```markdown
# [FEAT-ID]: [Feature Title]

## Overview
[2-3 sentences describing the feature and its value]

## Actors
- [Actor 1]: [role description]

## Acceptance Criteria

### AC-001: [Short description]
**Given** [precondition with concrete values]
**When** [action with specific input]
**Then** [expected outcome with measurable result]

### AC-002: ...

## Edge Cases
- [Edge case 1]: [expected behavior]

## Out of Scope
- [Explicitly excluded items]

## Risk Flags
- [ ] Database migration required
- [ ] Authentication/authorization changes
- [ ] Financial transaction logic
- [ ] PII/sensitive data handling
- [ ] Breaking API changes
- [ ] Infrastructure/deployment changes

## Dependencies
- [Upstream/downstream dependencies]
```

Create feature registry at `.sdlc/specs/[FEAT-ID]-registry.json`:
```json
{
  "feature_id": "[FEAT-ID]",
  "title": "[title]",
  "spec_file": "[FEAT-ID]-[slug]-spec.md",
  "spec_approved_at": null,
  "acceptance_criteria": [
    { "id": "AC-001", "description": "...", "test_function": null, "passes": null }
  ]
}
```

## Step 5 — Self-review (MANDATORY before presenting)

Run this checklist silently. Fix any failures before showing the spec to the user:

- [ ] Every AC uses Given/When/Then format
- [ ] Concrete values only — no "some value", "appropriate response", "valid input"
- [ ] Each AC is independently testable by DEV
- [ ] One interpretation per AC — if ambiguous, rewrite
- [ ] No implementation details — WHAT not HOW
- [ ] Edge cases section covers: null/empty inputs, boundary values, concurrent access, error states
- [ ] Risk flags reviewed — checked boxes have mitigation notes
- [ ] All domain terms match `.sdlc/domain-terms.md` exactly
- [ ] Out of scope section is explicit
- [ ] No duplicate or overlapping ACs

If you had to fix more than 3 items, re-run the checklist after fixes.

## Step 6 — Present and get approval

Present the spec to the user. Explicitly ask: "Approve this spec? Once approved, ACs become immutable."

On approval:
1. Set `spec_approved_at` in registry to current timestamp
2. Update GitHub Issue:
   ```bash
   gh issue comment [N] --body "## BA: Spec approved — [FEAT-ID]
   **ACs:** [count] acceptance criteria
   **Spec:** .sdlc/specs/[FEAT-ID]-[slug]-spec.md
   **Next:** DEV picks up for task breakdown (dev-split-tasks)"

   gh issue edit [N] --remove-label "adlc:needs-spec" --add-label "adlc:spec-approved"
   ```

</instructions>

<documents>
- `.sdlc/domain-context.md`
- `.sdlc/domain-terms.md`
- `.sdlc/specs/` — existing specs
- `.sdlc/KNOWLEDGE.md` — project patterns
</documents>
