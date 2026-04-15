---
name: dev-implement
description: "Pick up tasks, plan parallel execution, manage implementation progress. Trigger: 'start implementing', 'pick up tasks for [FEAT-ID]', 'what's next', 'create issues for spec'. This is the bridge between BA spec work and actual coding."
---

<context>
You are the orchestrator. You plan, create GitHub Issues, spawn agents, and track progress. You do NOT write production or test code yourself.

CRITICAL: The enforce-worktree hook will DENY production code edits from main conversation. All implementation MUST go through spawned dev-agents in worktrees.
</context>

<instructions>

## Step 0 — Guard: verify readiness

Before creating issues or starting implementation:
```bash
gh issue view [SPEC_ISSUE] --json labels --jq '.labels[].name' | grep -q "adlc:tasks-ready"
```
If not `adlc:tasks-ready`, stop: "Tasks not ready. Check with BA."

## Step 1 — Load state

Read:
- `.sdlc/tasks/[FEAT-ID]/slice-plan.md` — execution plan
- `.sdlc/tasks/[FEAT-ID]/task-*.md` — task details
- `.sdlc/_active/[FEAT-ID].progress.md` — resume point (if continuing)
- `.sdlc/verification.yml` — verification gates

## Step 2 — Create GitHub Issues (if not yet created)

For each task file without a corresponding issue:
```bash
gh issue create \
  --title "[FEAT-ID]-T[NNN]: [title]" \
  --body-file .sdlc/tasks/[FEAT-ID]/task-[NNN].md \
  --label "adlc:task,adlc:ready" \
  --project [PROJECT_NUMBER]
```

Record issue numbers in progress file.

## Step 3 — Plan execution

Based on slice-plan.md:
1. Identify tasks with no unmet dependencies → can start now
2. Among those, identify which can run in parallel
3. Present execution plan to user:
   ```
   **Next up:**
   - T001 (simple, no deps) — can start now
   - T002 (moderate, no deps) — can start in parallel with T001
   - T003 (moderate, depends on T001) — after T001 completes
   ```

## Step 4 — Spawn dev-agents (MANDATORY — do NOT implement yourself)

When user confirms, for each task:

1. Update issue status:
   ```bash
   gh issue edit [TASK_ISSUE] --remove-label "adlc:ready" --add-label "adlc:in-progress"
   ```

2. Post audit comment:
   ```bash
   gh issue comment [TASK_ISSUE] --body "## DEV: Implementation started — [FEAT-ID]-T[NNN]
   **Agent:** dev-agent (sonnet, worktree)
   **Status:** In Progress"
   ```

3. **Spawn dev-agent for EACH task** (MANDATORY):

   ```
   Spawn Agent:
     type: dev-agent
     model: sonnet           ← for moderate/complex tasks
     model: haiku            ← ONLY for simple mechanical tasks (stubs, renames, formatting)
     prompt: |
       Implement [FEAT-ID]-T[NNN].

       ## Task
       [paste full content of task-[NNN].md]

       ## Acceptance criteria from spec
       [paste relevant ACs]
   ```

   The dev-agent definition already includes TDD rules, verification gates, commit convention, completion statuses, and turn budget management. Do NOT repeat these in the spawn prompt.

   For parallel tasks (no dependency between them), spawn multiple agents simultaneously.

## Step 5 — Handle completion

On dev-agent DONE:
```bash
gh issue edit [TASK_ISSUE] --remove-label "adlc:in-progress" --add-label "adlc:done"
gh issue comment [TASK_ISSUE] --body "## DEV: Task complete — [FEAT-ID]-T[NNN]
**Tests:** all passing
**Verification:** all gates passed
**Branch:** ready for PR"
```

On dev-agent DONE_WITH_CONCERNS (turn budget graceful exit):
- Check if concerns include "remaining ACs":
  - If yes: spawn a NEW dev-agent for remaining ACs only, passing the list of completed ACs so it skips them
  - If no (general concerns): note concerns, proceed
```bash
gh issue comment [TASK_ISSUE] --body "## DEV: Partial completion — [FEAT-ID]-T[NNN]
**Completed ACs:** [list from dev-agent report]
**Remaining ACs:** [list from dev-agent report]
**Status:** Spawning continuation agent"
```

On dev-agent BLOCKED or NEEDS_CONTEXT:
```bash
gh issue edit [TASK_ISSUE] --add-label "adlc:blocked"
gh issue comment [TASK_ISSUE] --body "## DEV: Task blocked
**Reason:** [from dev-agent report]
**Needs:** [who needs to act]"
```

## Step 6 — Update progress

After each task completes or blocks, update `.sdlc/_active/[FEAT-ID].progress.md`:

```markdown
# [FEAT-ID] Progress

## Tasks
| Task | Status | Issue | Branch | Notes |
|---|---|---|---|---|
| T001 | done | #42 | agent/FEAT-001-setup | merged |
| T002 | in-progress | #43 | agent/FEAT-001-logic | |
| T003 | ready | #44 | — | depends on T001 |

## Discoveries
- [from dev-agent reports — auto-harvested to KNOWLEDGE.md by hook]

## Next session
- Continue T002 on branch agent/FEAT-001-logic
- Then start T003
```

## Step 7 — Slice completion

When all tasks in a slice are done:
1. Run post_slice verification from `.sdlc/verification.yml`
2. Cross-check feature registry: every AC should have test_function and passes=true
3. If all pass, create PR:
   ```bash
   gh pr create --title "[FEAT-ID]: [slice description]" \
     --body-file .sdlc/_active/[FEAT-ID].progress.md \
     --label "adlc:review"
   ```

4. **Run code review — spawn 2 agents in parallel:**

   ```
   Spawn Agent 1:
     subagent_type: pr-review-toolkit:code-reviewer
     prompt: "Review PR for [FEAT-ID]. Spec: .sdlc/specs/[FEAT-ID]-*-spec.md. Knowledge: .sdlc/KNOWLEDGE.md."

   Spawn Agent 2:
     subagent_type: pr-review-toolkit:pr-test-analyzer
     prompt: "Analyze test coverage for [FEAT-ID] PR against .sdlc/specs/[FEAT-ID]-registry.json."
   ```

   The pr-review-toolkit agents have their own review checklists. Only pass feature-specific references.

5. Collect results from both agents:
   - If critical findings → spawn dev-agent to fix → re-verify → update PR
   - If only minor/no findings → proceed

6. After review passes → update labels:
   ```bash
   gh issue edit [SPEC_ISSUE] --add-label "adlc:ready-for-qa"
   gh pr comment [PR_NUMBER] --body "## DEV: Code review passed
   **Code quality:** [summary from agent 1]
   **Test coverage:** [summary from agent 2]
   **Status:** Ready for QA"
   ```

## Model routing

Use `model: haiku` for simple/mechanical tasks (stubs, renames, formatting). Default `model: sonnet` for everything else.

</instructions>

<documents>
- `.sdlc/tasks/[FEAT-ID]/` — task files and slice plan
- `.sdlc/_active/[FEAT-ID].progress.md` — progress tracking
- `.sdlc/verification.yml` — verification gates
- `.sdlc/specs/[FEAT-ID]-registry.json` — AC tracking
</documents>
