# GitHub Ops — `gh` CLI templates

Reusable `gh` commands for `dev-implement` and `dev-bugfix`. Keep this file in sync with the label state machine below; edit here, not inline in SKILL.md.

## Label state machine

| Label | Transition trigger |
|---|---|
| `adlc:task` | Task issue created |
| `adlc:ready` | Task created, not started |
| `adlc:in-progress` | dev-agent spawned |
| `adlc:done` | dev-agent returned DONE + verification passed |
| `adlc:blocked` | dev-agent returned BLOCKED / NEEDS_CONTEXT / HUNG |
| `adlc:review` | PR opened, awaiting code review |
| `adlc:ready-for-qa` | Code review passed |

## Create task issues

```bash
gh issue create \
  --title "[FEAT-ID]-T[NNN]: [title]" \
  --body-file .sdlc/tasks/[FEAT-ID]/task-[NNN].md \
  --label "adlc:task,adlc:ready" \
  --project [PROJECT_NUMBER]
```

## Start a task

```bash
gh issue edit [TASK_ISSUE] --remove-label "adlc:ready" --add-label "adlc:in-progress"
gh issue comment [TASK_ISSUE] --body "## DEV: Implementation started — [FEAT-ID]-T[NNN]
**Agent:** dev-agent (sonnet, worktree)
**Status:** In Progress"
```

## Task done

```bash
gh issue edit [TASK_ISSUE] --remove-label "adlc:in-progress" --add-label "adlc:done"
gh issue comment [TASK_ISSUE] --body "## DEV: Task complete — [FEAT-ID]-T[NNN]
**Tests:** all passing
**Verification:** all gates passed
**Branch:** ready for PR"
```

## Partial completion (DONE_WITH_CONCERNS)

```bash
gh issue comment [TASK_ISSUE] --body "## DEV: Partial completion — [FEAT-ID]-T[NNN]
**Completed ACs:** [list from dev-agent report]
**Remaining ACs:** [list from dev-agent report]
**Status:** Spawning continuation agent"
```

## Blocked / hung task

```bash
gh issue edit [TASK_ISSUE] --add-label "adlc:blocked"
gh issue comment [TASK_ISSUE] --body "## DEV: Task blocked
**Reason:** [from dev-agent report or timeout]
**Turn at stop:** [N]/[maxTurns]
**Needs:** [who needs to act]"
```

## Open PR

```bash
gh pr create --title "[FEAT-ID]: [slice description]" \
  --body-file .sdlc/_active/[FEAT-ID].progress.md \
  --label "adlc:review"
```

## Review passed

```bash
gh issue edit [SPEC_ISSUE] --add-label "adlc:ready-for-qa"
gh pr comment [PR_NUMBER] --body "## DEV: Code review passed
**Code quality:** [summary from code-reviewer]
**Test coverage:** [summary from pr-test-analyzer]
**Status:** Ready for QA"
```
