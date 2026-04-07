---
name: start-session
description: Resume ADLC work — loads context, checks state, reports where you left off. Use at the start of every session.
---

# ADLC Start Session

Resume work from where the last session ended.

## Process

### Step 1: Load Context

1. Read CLAUDE.md for project overview
2. Read domain-context.md and domain-terms.md
3. Check agent memory for previous session notes
4. Read .sdlc/context-snapshot.md if it exists (created by PreCompact hook)

### Step 2: Check State

1. `git status` — any uncommitted changes?
2. `git log --oneline -10` — recent commits
3. `git branch` — current branch, any feature branches?
4. Check .sdlc/milestones/ — any active milestones?
5. For each active milestone:
   - Read feature-registry.json: how many ACs pass?
   - Read slice-plan.md if exists: which slice is current?
   - Read .sdlc/agent-log.txt: any warnings from last session?

### Step 3: Run Verification

Run pre_session commands from verification.yml:
- If any fail: report immediately (environment may need setup)

### Step 4: Report

Present status to user:

```
## Session Start

### Project: [name]
Stack: [from CLAUDE.md]

### Active Work
Milestone: [ID] — [title]
Progress: [X/Y ACs passing]
Current slice: [N] — [status]
Last activity: [from agent-log or git log]

### Environment
Branch: [current branch]
Uncommitted changes: [yes/no — summary if yes]
Verification: [pre_session results]

### Suggested Next Step
[Based on state: continue implementation / run review / fix failing tests / start new slice]
```

## Rules

- Never make changes during start-session — this is read-only reconnaissance
- If context-snapshot.md exists and is stale (>24h): note it but don't delete
- If no active milestones: suggest `/adlc:build-feature` or `/adlc:explore`
