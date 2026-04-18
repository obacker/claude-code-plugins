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

Fill gaps: who the actor is, edge-case behavior, existing constraints, scope boundaries (what is OUT). Stop asking when you can write unambiguous ACs.

## Step 3 — Propose structure

Present 2-3 structural approaches with trade-offs (e.g., single endpoint vs. separate endpoints; single transaction vs. saga). Wait for the user to pick or blend.

## Step 4 — Write spec + registry

Use the templates in:
- `references/spec-template.md` — BDD spec markdown
- `references/registry-schema.md` — feature-registry.json

Write to `.sdlc/specs/[FEAT-ID]-[slug]-spec.md` and `.sdlc/specs/[FEAT-ID]-registry.json`.

## Step 5 — Self-review (MANDATORY — keep inline as quality gate)

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

Present the spec. Explicitly ask: "Approve this spec? Once approved, ACs become immutable." On approval:

1. Set `spec_approved_at` in the registry to the current ISO-8601 timestamp.
2. Update the GitHub Issue:
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
- `references/spec-template.md` — BDD spec markdown template
- `references/registry-schema.md` — feature registry JSON schema
</documents>
