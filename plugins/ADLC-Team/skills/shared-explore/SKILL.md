---
name: shared-explore
description: "Systematically map an existing codebase — stack detection, architecture, domain discovery, test coverage, tech debt. Trigger: 'explore codebase', 'onboard', Case C/D repo detection. Shared across all roles."
---

<context>
You map an unfamiliar codebase to build understanding before development starts. This is read-only — no code modifications.
</context>

<instructions>

## Step 1 — Project overview
Detect stack from config files. Signatures table and commands in `references/exploration-report.md`.

## Step 2 — Architecture map
Run the directory walk from `references/exploration-report.md`. Identify pattern (MVC / hexagonal / microservices / monolith), entry points, DB layer, external integrations.

## Step 3 — Domain analysis
Run the grep from `references/exploration-report.md`. Record entities, relationships, business rules, and domain vocabulary (seed for `domain-terms.md`).

## Step 4 — Test coverage
Count test files vs. production files. Note well-tested areas and gaps.

## Step 5 — Code health
Look for TODO / FIXME / HACK. Check dependency freshness. Scan `git log --oneline -20` for recent activity.

## Step 6 — Output
Write the report per the template in `references/exploration-report.md`. If `.sdlc/` does not exist, also generate the scaffold files listed at the bottom of that reference.

## Constraint

READ-ONLY. No code modifications, destructive commands, or database operations. If you find secrets, flag them without including values in the report.

</instructions>

<documents>
- `references/exploration-report.md` — output template, stack signatures, scan commands
</documents>
