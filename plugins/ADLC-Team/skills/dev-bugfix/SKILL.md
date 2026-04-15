---
name: dev-bugfix
description: "Fast-track bug fix with root-cause analysis. Trigger: 'fix bug', 'hotfix', 'sửa bug', 'debug'. Lightweight path — skips spec/eval overhead."
---

<context>
Lightweight path for isolated bugs. Root cause FIRST, fix SECOND — no exceptions.
If scope exceeds a single bug, escalate to full spec workflow.

CRITICAL: You are the orchestrator. You investigate and plan, but you do NOT edit production/test code yourself. All code changes go through spawned agents in worktrees. The enforce-worktree hook will DENY any production code edits from main conversation.
</context>

<instructions>

## Phase 1 — Investigate (you do this in main conversation)

1. Read the bug report (GitHub Issue or user description)
2. Find the failing behavior: use Read, Grep, Glob to trace the code path
3. Check recent commits: `git log --oneline -20`
4. Formulate an explicit hypothesis: "The bug occurs because [X] when [Y]"

Do NOT skip this. Do NOT guess-and-fix.

If you cannot form a hypothesis, ask the user for more information.

## Phase 2 — Spawn dev-agent to fix (MANDATORY)

You MUST spawn a dev-agent. Do NOT edit code yourself.

```
Spawn Agent:
  type: dev-agent
  model: sonnet
  prompt: |
    Fix bug #[ISSUE]: [title].

    ## Root cause hypothesis
    [paste hypothesis and relevant code context]

    ## Test name
    Test_Bugfix_[IssueNumber]_[Behavior]

    ## Commit prefix
    fix(#[ISSUE])
```

The dev-agent definition handles TDD workflow, verification gates, and reporting. Only pass bug-specific context.

## Phase 3 — Spawn qa-agent to verify (MANDATORY)

After dev-agent completes with DONE, you MUST spawn a qa-agent.

```
Spawn Agent:
  type: qa-agent
  model: sonnet
  prompt: |
    Verify bugfix for #[ISSUE].

    ## What was fixed
    [paste dev-agent's report: root cause, fix, test name]

    ## Focus
    Write 2-3 adversarial tests: input variations, boundary conditions, regression scenarios.
```

The qa-agent definition handles verification gates and reporting format.

## Phase 4 — Document (you do this in main conversation)

After both agents complete:

```bash
# Update GitHub Issue
gh issue comment [ISSUE] --body "## DEV: Bug fixed
**Root cause:** [from dev-agent report]
**Fix:** [files changed]
**Test:** [test name]
**QA:** [qa-agent verdict]
**Verification:** all gates passed"

gh issue edit [ISSUE] --remove-label "bug" --add-label "adlc:done"
```

## Escalation criteria

Escalate to full spec workflow (ba-write-spec) if ANY apply:
- Fix requires changes to 4+ files
- Fix requires database migration
- Fix affects public API contract
- Fix requires changes to multiple features
- Root cause is architectural

</instructions>
