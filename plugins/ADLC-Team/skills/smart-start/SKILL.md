---
name: smart-start
description: "Start a session for any role (BA/DEV/QA). Auto-detects role from context or asks, loads shared state once, shows role-specific dashboard. Trigger: 'start session', 'start working', 'BA session', 'DEV session', 'QA session', 'start BA', 'start DEV', 'start QA', 'what needs doing'."
---

<context>
Unified session start for all roles. Loads shared context ONCE, then branches by role. Replaces ba-start, dev-start, qa-start.
</context>

<instructions>

## Step 1 — Detect role

If the user specified a role (BA/DEV/QA), use it. Otherwise infer from context:
- User mentions specs, features, requirements → BA
- User mentions code, implementation, tasks, bugs → DEV
- User mentions testing, QA, quality, edge cases → QA
- Ambiguous → ask: "Which role? BA / DEV / QA"

## Step 2 — Load shared context (once for all roles)

Read (skip missing silently):
- `CLAUDE.md` — project overview and conventions
- `.sdlc/domain-context.md` — business domain
- `.sdlc/domain-terms.md` — terminology
- `.sdlc/context-snapshot.md` — last session state
- `.sdlc/KNOWLEDGE.md` — project knowledge base
- `.sdlc/verification.yml` — verification gates

## Step 3 — Detect repo state

```bash
if [[ -d ".sdlc" ]]; then
  echo "SDLC_EXISTS"
elif git rev-parse --git-dir &>/dev/null; then
  echo "GIT_ONLY"
else
  echo "FRESH"
fi
```

If `GIT_ONLY` or `FRESH` → suggest running shared-explore first, regardless of role.

## Step 4 — Check GitHub state (role-specific queries)

**BA:**
```bash
gh issue list --label "adlc:needs-spec" --limit 20 --json number,title,labels
gh issue list --label "adlc:spec-draft" --limit 10 --json number,title
```

**DEV:**
```bash
gh issue list --label "adlc:spec-approved" --limit 10 --json number,title
gh issue list --label "adlc:ready" --limit 20 --json number,title,labels
gh issue list --label "adlc:in-progress" --limit 10 --json number,title,assignees
gh issue list --label "adlc:blocked" --limit 10 --json number,title
gh pr list --state open --limit 10 --json number,title,reviewDecision
```

**QA:**
```bash
gh issue list --label "adlc:ready-for-qa" --limit 20 --json number,title,labels
gh issue list --label "adlc:spec-draft" --limit 10 --json number,title
gh issue list --label "adlc:qa-failed" --limit 10 --json number,title
gh issue list --label "adlc:done" --limit 10 --json number,title,updatedAt
```

DEV also checks:
```bash
git branch --list "agent/*" 2>/dev/null
find .sdlc/_active/ -name "*.progress.md" 2>/dev/null
```

## Step 5 — Present role dashboard

Show a concise summary with counts and top items. End with:
- **Suggested next action:** [highest priority item]
- Role-specific options (invoke the appropriate skill)

**BA options:** write spec (ba-write-spec), review domain terms, explore codebase (shared-explore)
**DEV options:** split tasks (dev-split-tasks), implement (dev-implement), fix bug (dev-bugfix), explore (shared-explore)
**QA options:** adversarial tests (qa-test-adversarial), UI tests (shared-write-ui-tests), spec AC review, exploratory test planning

</instructions>
