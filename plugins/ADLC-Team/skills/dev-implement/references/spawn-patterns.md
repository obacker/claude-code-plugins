# Spawn Patterns — agent invocation templates

Templates used by `dev-implement` Step 4 and Step 7, and by `dev-bugfix` Phase 2–3. Task files are referenced by path, never pasted inline, to keep parallel-spawn memory down.

## dev-agent — task implementation

```
Spawn Agent:
  type: dev-agent
  model: [sonnet | haiku]       ← see "Model routing" below
  isolation: worktree
  prompt: |
    Implement [FEAT-ID]-T[NNN].
    Task file: .sdlc/tasks/[FEAT-ID]/task-[NNN].md
    Registry: .sdlc/specs/[FEAT-ID]-registry.json
    Read both files first, then proceed with TDD.
```

The dev-agent definition already knows TDD rules, verification gates, commit convention, completion statuses, and turn budget behavior. Do NOT repeat them in the spawn prompt.

## qa-agent — bugfix verification

```
Spawn Agent:
  type: qa-agent
  model: sonnet
  isolation: worktree
  prompt: |
    Verify bugfix for #[ISSUE].
    DEV report: [paste dev-agent's short summary — root cause + test name only]
    Focus: 2–3 adversarial tests (input variations, boundary conditions, regression).
```

## pr-review-toolkit — sequential review (P1-T5)

Run sequentially, not in parallel, so the test analyzer can reference the code reviewer's output.

```
Step 7a — Spawn pr-review-toolkit:code-reviewer
  Model: sonnet
  Prompt: "Review PR for [FEAT-ID].
           Spec: .sdlc/specs/[FEAT-ID]-*-spec.md
           Knowledge: .sdlc/KNOWLEDGE.md"

Step 7b — Spawn pr-review-toolkit:pr-test-analyzer
  Model: sonnet  (haiku if PR diff < 200 lines)
  Prompt: "Analyze test coverage for [FEAT-ID] PR.
           Registry: .sdlc/specs/[FEAT-ID]-registry.json
           Previous reviewer output path: [path produced by Step 7a]"
```

## Model routing (MANDATORY — not optional)

Route to `model: haiku` for these patterns. The orchestrator must pick haiku automatically when the task matches; default to sonnet otherwise.

- File rename / move only
- Add stub or skeleton (no logic)
- Formatting / linting fix
- Comment-only changes
- Single-line config value change
- Dependency version bump (no breaking change)

For architectural work, multi-file changes, or any business logic: `model: sonnet`. The dev-agent's `advisor` frontmatter auto-escalates to Opus when complexity crosses the configured threshold.

## Timeout policy (MANDATORY for every spawn)

Apply a 10-minute wall-clock timeout to every dev-agent / qa-agent spawn. If no status report arrives within 10 minutes:

1. Mark agent as HUNG — comment the task issue with `adlc:blocked`
2. Force-remove the worktree: `git worktree remove --force agent/[branch]`
3. Report to user: "Agent hung at turn [N]/[maxTurns] on [file/command]"
4. Offer three recovery options:
   - (a) Split the task smaller and respawn
   - (b) Switch the model to haiku and respawn
   - (c) Skip and escalate to BA

## Parallel execution limits

- **Maximum 2 dev-agents simultaneously.** Queue any extras.
- 3+ independent tasks → spawn 2, wait for 1 to reach DONE, then spawn the next.
- Rationale: 3 parallel agents × ~150K context ≈ 450K peak tokens → RAM spike + IDE freeze on team machines. 2 agents yields ~75% of the parallelism benefit at ~50% of the RAM cost.

## Turn-status reading

Agents emit `TURN_STATUS: turn=N/MAX ...` lines at turns 10/20/25. Use these to decide:
- Making progress (acs_done increasing) → extend timeout if needed.
- No progress for 2 status emissions → treat as HUNG, apply timeout policy.
