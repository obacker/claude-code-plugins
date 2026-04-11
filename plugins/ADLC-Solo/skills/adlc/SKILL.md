---
name: adlc
description: "Smart ADLC entry point — auto-detects project state and routes to the right workflow. Use as default starting command."
argument-hint: "Optional: feature description, bug report, or milestone ID"
---

# ADLC — Smart Router

Auto-detect project state and route to the correct ADLC workflow.

## Process

### Step 1: Read Project State

1. Check if `.sdlc/` directory exists
2. If `.sdlc/context-snapshot.md` exists: read it for last session state
3. Check `.sdlc/milestones/` for active milestones:
   - For each milestone: read `feature-registry.json` for AC pass/fail status
   - Check for `slice-plan.md` existence
4. Read `git status` — any uncommitted changes? Current branch?
5. Read `git log --oneline -5` — recent activity

### Step 2: Parse User Intent

If the user provided $ARGUMENTS:
- Looks like a **bug report** (contains "bug", "error", "fix", "broken", "crash", "fail"): → route to bugfix
- Looks like a **feature request** (contains "add", "implement", "build", "create", "new"): → route to build-feature
- Looks like a **milestone ID** (matches pattern M[0-9]+): → route to plan-slice or build-feature for that milestone
- Looks like "explore" or "map": → route to explore
- Ambiguous: → present options to user

### Step 3: Route Based on State + Intent

| Project State | User Intent | Route |
|--------------|-------------|-------|
| No `.sdlc/` directory | Any | `/adlc:explore` — need to map codebase first |
| `.sdlc/` exists, no milestones | Feature request | `/adlc:build-feature $ARGUMENTS` |
| `.sdlc/` exists, no milestones | Bug report | `/adlc:bugfix $ARGUMENTS` |
| Active milestone, ACs pending | No arguments | `/adlc:start-session` — resume work |
| Active milestone, ACs pending | Feature (same milestone) | Continue `/adlc:build-feature` for current milestone |
| Active milestone, ACs pending | Feature (different) | Ask: finish current milestone first, or start new? |
| Active milestone, all ACs passing | No arguments | `/adlc:review-slice` — validate the completed slice |
| Active milestone, all ACs passing | New feature | `/adlc:build-feature $ARGUMENTS` — start next feature |
| No active work, session start | No arguments | `/adlc:start-session` |

### Step 4: Present and Confirm

Present your recommendation to the user:

```
## ADLC Router

**Project state**: [summary — e.g., "Milestone M003 active, 4/7 ACs passing, on branch feature/coa-tree"]
**Your request**: [parsed intent — e.g., "New feature: add user authentication"]
**Recommended action**: [skill name and description]

Proceed with [skill]? Or choose a different workflow:
- /adlc:build-feature — Full feature lifecycle
- /adlc:bugfix — Lightweight bug fix
- /adlc:explore — Map existing codebase
- /adlc:plan-milestone — Plan milestones for an epic
- /adlc:plan-slice — Break milestone into tasks
- /adlc:review-slice — Post-slice validation
- /adlc:start-session — Resume from last session
```

Wait for user confirmation before executing the recommended skill.

## Rules

- This skill is READ-ONLY reconnaissance + routing. Never modify files.
- Always present a recommendation — don't just dump state and ask "what do you want?"
- If multiple milestones are active: flag this as unusual and ask which to focus on.
- If uncommitted changes exist: mention them prominently — user may need to commit or stash first.
- Default to the most productive next step, not the safest. If work is in progress, default to resuming it.
