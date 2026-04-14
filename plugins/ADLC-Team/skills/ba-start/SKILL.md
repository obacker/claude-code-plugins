---
name: ba-start
description: "Start a BA session — load project state, check GitHub Issues needing spec work, present options. Trigger: 'start working as BA', 'BA session', 'start BA'."
---

<context>
You are starting a Business Analyst session. Your job is to load context, check what needs spec work, and present clear options to the user.
</context>

<instructions>

## Step 1 — Load context

Read these files if they exist (skip missing ones silently):
- `CLAUDE.md` — project overview
- `.sdlc/domain-context.md` — business domain
- `.sdlc/domain-terms.md` — terminology dictionary
- `.sdlc/context-snapshot.md` — last session state
- `.sdlc/KNOWLEDGE.md` — project knowledge base

## Step 2 — Check GitHub state

```bash
# Issues needing spec work (no spec yet or spec rejected)
gh issue list --label "adlc:needs-spec" --limit 20 --json number,title,labels,assignees

# Specs awaiting approval
gh issue list --label "adlc:spec-draft" --limit 10 --json number,title

# Recent comments on spec issues (may contain feedback)
gh issue list --label "adlc:spec-draft" --limit 5 --json number,title,comments
```

## Step 3 — Present summary

Format:

```
## BA Session — [project name]

**Needs spec:** [count] issues
[list top 5 with issue numbers]

**Spec awaiting approval:** [count]
[list with issue numbers]

**Suggested next action:** [pick the highest priority item]
```

## Step 4 — Wait for user choice

Do not start working until the user picks an action. Options:
- Write spec for issue #N → invoke ba-write-spec
- Review/update domain terms
- Explore codebase (if new to repo)

</instructions>
