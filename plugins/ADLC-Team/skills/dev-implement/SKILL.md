---
name: dev-implement
description: "Pick up tasks, plan parallel execution, manage implementation progress. Trigger: 'start implementing', 'pick up tasks for [FEAT-ID]', 'what's next', 'create issues for spec'. This is the bridge between BA spec work and actual coding."
---

<context>
You are the orchestrator. You plan, create GitHub Issues, spawn agents, and track progress. You do NOT write production or test code yourself.

CRITICAL: The pretooluse-guard hook will DENY production code edits from main conversation. All implementation MUST go through spawned dev-agents in worktrees.
</context>

<instructions>

## Step 0 — Guard: verify readiness

```bash
gh issue view [SPEC_ISSUE] --json labels --jq '.labels[].name' | grep -q "adlc:tasks-ready"
```
If not `adlc:tasks-ready`, stop: "Tasks not ready. Check with BA."

## Step 1 — Load state

Follow `skills/_shared/load-sdlc-context.md` for the standard file set, plus:
- `.sdlc/tasks/[FEAT-ID]/slice-plan.md` — execution plan
- `.sdlc/tasks/[FEAT-ID]/task-*.md` — task details (paths only; dev-agents read them)

## Step 2 — Create GitHub Issues

For each task file without a corresponding issue, use the `gh issue create` template in `references/github-ops.md`. Record issue numbers in the progress file.

## Step 3 — Plan execution

From `slice-plan.md`:
1. Identify tasks whose dependencies are met.
2. Of those, identify which can run in parallel — **capped at 2** (see `references/spawn-patterns.md` → Parallel execution limits).
3. Present to user:
   ```
   **Next up:**
   - T001 (simple, no deps) — start now (haiku — stub only)
   - T002 (moderate, no deps) — parallel with T001 (sonnet)
   - T003 (moderate, depends on T001) — queued
   ```

## Step 4 — Spawn dev-agents (MANDATORY — do NOT implement yourself)

For each task to spawn:
1. Transition labels with the "Start a task" template in `references/github-ops.md`.
2. Spawn using the **dev-agent — task implementation** template in `references/spawn-patterns.md`. The prompt references the task file path, not its content. Model selection follows the MANDATORY routing table in the same reference.
3. Apply the **Timeout policy** block from `references/spawn-patterns.md` (10-minute wall-clock, HUNG recovery choices).
4. Respect the **Parallel execution limits** (max 2 concurrent dev-agents).

## Step 5 — Handle completion

On DONE, DONE_WITH_CONCERNS, BLOCKED, NEEDS_CONTEXT, or HUNG: use the matching templates in `references/github-ops.md`. On DONE_WITH_CONCERNS with remaining ACs, spawn a continuation dev-agent for the remaining set only (pass the completed AC list so it skips them).

**Advisor escalation**: if the dev-agent exits with `DONE_WITH_CONCERNS` tagged `needs-orchestrator-advisor` (or the ba-agent surfaces a structural dilemma), call the `advisor` tool BEFORE deciding the next move. You run on sonnet — the advisor reaches a stronger Opus reviewer. This is the intended escalation path for architectural decisions, spec ambiguity, multi-file churn, and repeated verification failures. Do not respawn blindly; let the advisor's guidance shape the next spawn's constraints.

## Step 6 — Update progress

After each task completes or blocks, append to `.sdlc/_active/[FEAT-ID].progress.md`:

```markdown
| Task | Status | Issue | Branch | Notes |
|---|---|---|---|---|
| T001 | done | #42 | agent/FEAT-001-setup | merged |
```

## Step 7 — Slice completion

When all tasks in a slice are done:
1. Run `post_slice` verification from `.sdlc/verification.yml`.
2. Cross-check registry: every AC must have `test_function` + `passes=true`.
3. Open PR (see `references/github-ops.md`).
4. **Run code review — sequentially** per the "pr-review-toolkit — sequential review" template in `references/spawn-patterns.md`. Do NOT spawn the two reviewers in parallel — the test analyzer reads the code reviewer's output.
5. On review pass, apply the "Review passed" template in `references/github-ops.md`. On critical findings, spawn a dev-agent to fix → re-verify → update PR.

</instructions>

<documents>
- `.sdlc/tasks/[FEAT-ID]/` — task files and slice plan
- `.sdlc/_active/[FEAT-ID].progress.md` — progress tracking
- `.sdlc/verification.yml` — verification gates
- `.sdlc/specs/[FEAT-ID]-registry.json` — AC tracking
- `skills/_shared/load-sdlc-context.md` — shared state-loading
- `skills/dev-implement/references/github-ops.md` — `gh` CLI templates
- `skills/dev-implement/references/spawn-patterns.md` — agent spawn templates, routing, timeout, parallel cap
</documents>
