---
name: dev-start
description: "Start a DEV session — load project state, detect repo mode, check tasks ready for implementation. Trigger: 'start working as DEV', 'DEV session', 'start dev'."
---

<context>
You are starting a Developer session. Load context, detect what state the repo is in, and present actionable options.
</context>

<instructions>

## Step 1 — Detect repo mode

Check the repo state to determine which case applies:

| Case | Condition | Action |
|---|---|---|
| A | `.sdlc/` exists + tasks in progress | Resume work |
| B | `.sdlc/` exists + tasks ready | Pick up new tasks |
| C | Git repo exists but no `.sdlc/` | Run explore skill first |
| D | No git repo | Initialize project |

```bash
# Detect case
if [[ -d ".sdlc" ]]; then
  IN_PROGRESS=$(find .sdlc/_active/ -name "*.progress.md" 2>/dev/null | wc -l)
  TASKS_READY=$(gh issue list --label "adlc:ready" --limit 1 --json number 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
  if [[ "$IN_PROGRESS" -gt 0 ]]; then
    echo "CASE_A"
  elif [[ "$TASKS_READY" -gt 0 ]]; then
    echo "CASE_B"
  else
    echo "CASE_B_EMPTY"
  fi
elif git rev-parse --git-dir &>/dev/null; then
  echo "CASE_C"
else
  echo "CASE_D"
fi
```

## Step 2 — Load context

Read (skip missing files silently):
- `CLAUDE.md` — project overview and conventions
- `.sdlc/context-snapshot.md` — last session state
- `.sdlc/KNOWLEDGE.md` — project knowledge base
- `.sdlc/verification.yml` — verification gates
- `.sdlc/_active/*.progress.md` — work in progress

## Step 3 — Check GitHub state

```bash
# Specs approved, ready for task breakdown
gh issue list --label "adlc:spec-approved" --limit 10 --json number,title

# Tasks ready for pickup
gh issue list --label "adlc:ready" --limit 20 --json number,title,labels

# Tasks in progress (by any agent)
gh issue list --label "adlc:in-progress" --limit 10 --json number,title,assignees

# Blocked tasks
gh issue list --label "adlc:blocked" --limit 10 --json number,title

# Recent PR reviews needing attention
gh pr list --state open --limit 10 --json number,title,reviewDecision
```

## Step 4 — Check for active branches

```bash
# List feature branches
git branch --list "agent/*" 2>/dev/null

# Check for uncommitted work
git status --porcelain 2>/dev/null
```

## Step 5 — Present summary

```
## DEV Session — [project name] (Case [A/B/C/D])

**Specs ready for task breakdown:** [count]
[list with issue numbers — invoke dev-split-tasks]

**In progress:** [count] tasks
[list with branch names and last activity]

**Ready to pick up:** [count] tasks
[list with complexity and dependencies]

**Blocked:** [count] tasks
[list with blocker reason]

**Open PRs:** [count]
[list with review status]

**Suggested next action:** [highest priority item]
```

## Step 6 — Wait for user choice

Options:
- Split spec into tasks → invoke dev-split-tasks
- Continue task on branch X → resume implementation
- Pick up task #N → invoke dev-implement
- Fix bug → invoke dev-bugfix
- Review codebase → invoke shared-explore
- Run verification gates

</instructions>
