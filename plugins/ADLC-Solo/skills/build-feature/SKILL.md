---
name: build-feature
description: Full ADLC feature lifecycle — spec, plan, implement, review, QA, verify. Use for any new feature or significant enhancement.
argument-hint: Feature description (e.g., "add user authentication with JWT")
---

# ADLC Build Feature

Structured feature development with BDD specs, agent isolation, and verification gates.

## Prerequisites

This skill requires companion plugins. Before proceeding, verify they are installed:
- **pr-review-toolkit** (required for Phase 6 — code quality review)
- **commit-commands** (required for Phase 8 — git operations)

If either is missing, inform the user: "Install required companion plugins first. See README."

## Principles

- Spec first, code second — no implementation without approved ACs
- Immutable spec after approval — protected by PreToolUse hook
- Each dev task in isolated worktree — enforced by frontmatter
- Review + QA mandatory for every slice — no exceptions
- Verification gates at every stage — fail = stop
- Use TodoWrite to track progress through all phases

---

## Gate Enforcement

Each phase transition has a hard gate with a verification command. You CANNOT advance to the next phase without passing its gate. If a gate fails: fix and re-run. Do NOT skip.

| Phase Transition | Gate Verification |
|-----------------|-------------------|
| Discovery → Specification | User confirmed understanding |
| Specification → Slice Planning | `test -f .sdlc/milestones/[ID]/milestone-spec.md` + user said "approved" + `spec_approved_at` set in feature-registry.json |
| Slice Planning → Implementation | User approved slice plan |
| Implementation → Review | All dev-agents returned DONE or DONE_WITH_CONCERNS + zero compile errors (run `go vet ./...` or `tsc --noEmit`) |
| Review (Spec) → Review (Quality) | qa-spec-checker reports PASS or PASS_WITH_CONCERNS |
| Review (Quality) → Verification | Critical findings resolved |
| Verification → Summary | All verification.yml post_slice commands exit 0 + feature-registry cross-check clean + `grep -r 'TODO\|FIXME' [changed files]` returns zero results |
| Summary → Done | All AC statuses updated in feature-registry.json + knowledge capture complete |

---

## Phase 1: Discovery

Feature request: $ARGUMENTS

1. Create TodoWrite with phases: Discovery, Specification, Slice Planning, Implementation, Review (Spec Compliance), Review (Code Quality), Verification, Summary
2. Read domain-context.md and domain-terms.md
3. Read CLAUDE.md for project stack and commands
4. If unclear: ask user (max 3 questions, one at a time)
5. Confirm understanding with user in 2-3 sentences

Mark Discovery complete.

---

## Phase 2: Specification

1. Determine milestone ID: read .sdlc/milestones/ for existing IDs, use next sequential
2. Create directory: `.sdlc/milestones/[MILESTONE-ID]/`
3. Launch **spec-writer** agent:
   ```
   Agent: spec-writer
   Input: Confirmed feature description + domain context summary
   ```
4. spec-writer produces: milestone-spec.md + feature-registry.json
5. Present milestone-spec.md to user — show each AC clearly
6. Ask user: "Approve these ACs? After approval they become immutable."

**GATE: User must explicitly say "approved" or equivalent.**

After approval:
- Set `spec_approved_at` in feature-registry.json to current ISO timestamp
- From this point, protect-spec.py hook blocks any Edit/Write to milestone-spec.md

Mark Specification complete.

---

## Phase 3: Slice Planning

1. Read approved milestone-spec.md
2. Check if `.sdlc/milestones/[MILESTONE-ID]/slice-plan.md` already exists (from `/adlc:plan-slice`):
   - If exists: load it, present to user for confirmation, skip to step 5
   - If not: decompose from scratch (continue below)
3. Decompose ACs into implementation tasks (dev-agent has **35-turn budget** — size tasks accordingly):
   - Each task: max 3 files, 1-2 ACs, completable in ~15-25 turns of TDD
   - If a task would touch 4+ files: split it — dev-agent will hit turn limits
   - Each task specifies: which files to create/modify, which ACs it covers, dependencies on other tasks
4. Group tasks into slices:
   - Each slice: half-day of work, 2-3 tasks
   - Independent tasks within a slice CAN be parallelized
   - Dependent tasks MUST be sequential
5. For each task, specify:
   - Exact file paths to create or modify
   - Which ACs this task covers
   - Whether it can run in parallel with other tasks in the slice
   - Expected test names: `Test_[Feature]_AC[N]_[Behavior]`
6. Present slice plan to user:
   ```
   Slice 1 (tasks 1-3, ~half day):
     Task 1: [description] → AC1, AC2 → files: src/... [PARALLEL]
     Task 2: [description] → AC3 → files: src/... [PARALLEL]
     Task 3: [description] → AC4 → files: src/... [DEPENDS: Task 1]
   ```

**GATE: User approves slice plan before implementation.**

Mark Slice Planning complete.

---

## Phase 4: Implementation

**REQUIRES USER APPROVAL FROM PHASE 3.**

1. Run pre_session commands from verification.yml:
   ```bash
   # Read verification.yml, execute pre_session commands
   # If ANY command fails → STOP and report to user
   ```

2. For each slice, in order:
   a. Identify which tasks in this slice are independent (can parallelize)
   b. **Spawn dev-agent for each task:**
      - Independent tasks: **spawn in parallel (multiple Agent calls in ONE message)**
      - Dependent tasks: spawn sequentially after dependency completes
   c. Each dev-agent receives:
      - Task description with exact file scope
      - Relevant ACs from milestone-spec.md
      - Path to verification.yml
      - Path to feature-registry.json
   d. Each dev-agent gets its own worktree automatically (`isolation: worktree` in frontmatter)
   e. **Model routing** (override agent default via spawn-time `model:` parameter):
      - Task touches ≤2 files with complete spec → spawn dev-agent with `model: haiku`
      - Task touches multiple files or requires judgment → use agent default (`model: sonnet`)
      - Task requires architectural decisions → spawn dev-agent with `model: opus`
   f. Wait for all dev-agents in this slice to return
   g. Collect results: check each agent's completion status
      - **DONE**: proceed
      - **DONE_WITH_CONCERNS**: check if concerns include "remaining ACs":
        - If yes (turn budget graceful exit): spawn NEW dev-agent for remaining ACs only, passing completed ACs list so it skips them
        - If no (general concerns): note concerns, proceed
      - **NEEDS_CONTEXT**: provide context and re-spawn
      - **BLOCKED**: report to user, decide whether to skip or fix
   h. **Read agent log**: After each dev-agent returns, read `.sdlc/agent-log.txt` for warnings surfaced by the SubagentStop hook. Investigate any warnings before proceeding.
   i. **Auto-retry on failure** (track retry count per task — start at 0):
      - If error is "tool-use limit exhausted": retry_count += 1, spawn NEW dev-agent for remaining ACs only, pass completed ACs list and context from failed agent's last commit
      - If error is "merge conflict": retry_count += 1, run `git merge --abort` in worktree, re-spawn dev-agent with updated base branch
      - If error is unknown: do NOT retry — report to user immediately with diagnostics from `.sdlc/agent-log.txt`
      - **Stop condition**: if retry_count >= 2 for the same task → STOP retrying, escalate to user: "Task [N] failed after 2 retries. Errors: [list]. Manual intervention required."

3. After all slices complete: proceed to Phase 5

Mark Implementation complete.

---

## Phase 5: Review — Stage 1: Spec Compliance

**CRITICAL: BOTH stages of review are MANDATORY. Do NOT skip either.**

**Stage 1 must pass before Stage 2 begins.**

1. Launch **qa-spec-checker** agent for **Spec Compliance**:
   ```
   Agent: qa-spec-checker (platform-enforced model: haiku)
   Input: milestone-spec.md, feature-registry.json, list of changed files
   ```
   - Runs in main working tree (NOT isolated — needs to see merged dev-agent code)
   - Checks: every AC has a test, every test passes, no extra scope
   - **Spec compliance must PASS before proceeding to adversarial testing.**

2. Launch **qa-adversarial** agent for **Adversarial Testing**:
   ```
   Agent: qa-adversarial (platform-enforced model: sonnet)
   Input: milestone-spec.md, feature-registry.json, list of changed files, spec compliance results
   ```
   - Runs in main working tree
   - Tries to break the implementation: invalid inputs, boundary values, auth bypass, injection, etc.

3. If spec compliance fails:
   - Identify which ACs are not covered or failing
   - Spawn dev-agent(s) to fix specific failures
   - Re-run qa-spec-checker on fixed areas
   - **Loop max 3 times. Still failing → report to user.**

Mark Review (Spec Compliance) complete only when qa-spec-checker reports PASS or PASS_WITH_CONCERNS.

---

## Phase 6: Review — Stage 2: Code Quality

1. Launch pr-review-toolkit agents in parallel:
   - **code-reviewer**: bugs, logic errors, CLAUDE.md compliance
   - **silent-failure-hunter**: swallowed errors, missing error handling
   - **pr-test-analyzer**: test coverage quality, flaky test patterns
2. Collect and consolidate findings from all reviewers
3. Present to user:
   - Critical findings (must fix before merge)
   - Important findings (should fix)
   - Minor findings (nice to fix)
4. Ask user: "Fix critical issues now? Fix all? Accept as-is?"
5. If fixing:
   - Spawn dev-agent(s) for specific fixes
   - Re-run relevant reviewers on fixed code
   - **Do NOT re-run spec compliance (already passed in Stage 1)**

Mark Review (Code Quality) complete.

---

## Phase 7: Verification

1. Run post_slice commands from verification.yml:
   ```bash
   # Execute each command from verification.yml post_slice section
   # Record: command, exit code, output summary
   ```
2. Feature-registry cross-check:
   - Read feature-registry.json
   - For every AC with `passes: true`:
     - Grep for test function name in test files
     - Test must exist AND not be skipped/commented out
     - Run the specific test — must pass
   - For every AC with `passes: false`:
     - This is a gap — report it
   - Mismatch between registry and actual test results → flag and report
3. If verification fails:
   - Present failures with exact output to user
   - Ask: fix now or accept known gaps?
   - If fixing: spawn dev-agent, re-verify
4. If all pass: proceed to Summary

**GATE: User approves slice completion.**

Mark Verification complete.

---

## Phase 8: Summary

1. Mark all TodoWrite items complete
2. Present final summary:

```
## Feature Complete: [Feature Name]

### Changes
- Files created: [list]
- Files modified: [list]
- Total commits: [N]

### AC Coverage
| AC ID | Description | Test | Status |
|-------|-------------|------|--------|
| AC1   | ...         | Test_...  | PASS |

### Review Results
- Spec compliance: PASS
- Code quality: [summary of findings and resolutions]
- Adversarial testing: [X critical, Y warning, Z note]

### Verification
- Build: PASS
- Lint: PASS
- Tests: X/Y passing
- Coverage: [if available]

### Key Decisions
- [decisions made during implementation]

### Follow-up Items
- [anything deferred or noted for future work]
```

3. **Knowledge Capture** — update project knowledge from what was learned:

   a. **domain-context.md** — If implementation revealed undocumented constraints, integration quirks, or architectural assumptions, add them. Skip if nothing new.
   b. **domain-terms.md** — If new terminology emerged or existing terms were clarified, update. Skip if nothing new.
   c. **CLAUDE.md** — If new commands, conventions, or stack details were discovered, update. Skip if nothing new.
   d. **`.sdlc/_active/session-context.md`** — Create/update with:
      - What was built (AC status table from summary above)
      - Production-critical findings from review/QA
      - Deferred items with blockers
      - Quality gate results
      - Next session starting point
   e. **`.sdlc/_active/CAPTURES.md`** — Append any:
      - Concerns discovered during implementation that weren't resolved
      - TODOs that couldn't be addressed in this feature scope
      - Ideas for improvement or refactoring opportunities
      - Edge cases found by QA that were accepted as known limitations
   f. **Auto-memory** — Save to memory only if something non-obvious was learned that future features should know. Skip if the code and commits are self-explanatory.

   If nothing was learned (straightforward feature, no surprises): skip all updates.

4. Ask user: "Create PR with commit-commands?" If yes:
   ```
   Use /commit-commands:commit-push-pr to create branch, commit, push, and open PR
   ```

Mark Summary complete.
