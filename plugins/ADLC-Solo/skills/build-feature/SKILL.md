---
description: Full ADLC feature lifecycle — spec, plan, implement, review, QA, verify. Use for any new feature or significant enhancement.
argument-hint: Feature description (e.g., "add user authentication with JWT")
---

# ADLC Build Feature

Structured feature development with BDD specs, agent isolation, and verification gates.

## Prerequisites

This skill requires companion plugins. Before proceeding, verify they are installed:
- **pr-review-toolkit** (required for Phase 6 — code quality review)
- **commit-commands** (required for Phase 9 — git operations)

If either is missing, inform the user: "Install required companion plugins first. See README."

## Principles

- Spec first, code second — no implementation without approved ACs
- Immutable spec after approval — protected by PreToolUse hook
- Each dev task in isolated worktree — enforced by frontmatter
- Review + QA mandatory for every slice — no exceptions
- Verification gates at every stage — fail = stop
- Use TodoWrite to track progress through all phases

---

## Phase 0: Activate Enforcement

1. Create `.sdlc/` directory if it doesn't exist
2. Create `.sdlc/.enforce-worktree` flag file (activates the PreToolUse hook that blocks production code edits on main)
3. This flag is removed in Phase 9 (Summary) after completion

---

## Phase 1: Discovery

Feature request: $ARGUMENTS

1. Create TodoWrite with phases: Discovery, Specification, Slice Planning, Implementation, Review (Spec Compliance), Review (Code Quality), Verification, Knowledge Capture, Summary
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
3. Decompose ACs into implementation tasks:
   - Each task: 1-2 hours of work, clear file scope, maps to specific ACs
   - Each task specifies: which files to create/modify, which ACs it covers, dependencies on other tasks
3. Group tasks into slices:
   - Each slice: half-day of work, 2-3 tasks
   - Independent tasks within a slice CAN be parallelized
   - Dependent tasks MUST be sequential
4. For each task, specify:
   - Exact file paths to create or modify
   - Which ACs this task covers
   - Whether it can run in parallel with other tasks in the slice
   - Expected test names: `Test_[Feature]_AC[N]_[Behavior]`
5. Present slice plan to user:
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

**DO NOT implement tasks yourself. You MUST spawn dev-agents for ALL implementation work.**

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
      - **DONE_WITH_CONCERNS**: note concerns, proceed
      - **NEEDS_CONTEXT**: provide context and re-spawn
      - **BLOCKED**: report to user, decide whether to skip or fix

3. After all slices complete: proceed to Phase 5

### Anti-Rationalization List (Implementation)

- "I'll just fix it myself, faster than spawning an agent" → That's how enforcement breaks. Delegate.
- "Too simple for a worktree" → Isolation is not about complexity. It's about safety and discipline.
- "Just one quick edit on main" → One exception becomes the norm. Use the worktree.
- "The agent will get confused, let me do it" → Write a clearer prompt. Don't bypass the process.
- "I'll spawn the agent later, let me start the code first" → Start with the agent. No production code from orchestrator.
- "This is just a config change, not real code" → If it's in the source tree and not .sdlc/, it goes through dev-agent.

Mark Implementation complete.

---

## Phase 5: Review — Stage 1: Spec Compliance

**CRITICAL: BOTH stages of review are MANDATORY. Do NOT skip either.**

**Stage 1 must pass before Stage 2 begins.**

1. Launch **qa-tester** agent (runs in main working tree, NOT isolated — needs to see merged dev-agent code):
   ```
   Agent: qa-tester
   Input: milestone-spec.md, feature-registry.json, list of changed files
   Mode: Spec compliance first, then adversarial
   ```
2. qa-tester checks:
   - Every AC has a corresponding test
   - Every test passes
   - No extra scope (implementation doesn't do more than spec requires)
   - Adversarial tests for edge cases
3. If spec compliance fails:
   - Identify which ACs are not covered or failing
   - Spawn dev-agent(s) to fix specific failures
   - Re-run qa-tester on fixed areas
   - **Loop max 3 times. Still failing → report to user.**

Mark Review (Spec Compliance) complete only when qa-tester reports PASS or PASS_WITH_CONCERNS.

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

## Phase 8: Knowledge Capture

**Knowledge decays if not written down. Update project knowledge BEFORE summarizing.**

1. **domain-context.md** — Review what was built and check if domain-context.md needs updates:
   - New modules, services, or architectural components introduced?
   - New integration points or external dependencies?
   - Changed data flow or processing pipeline?
   - If any of the above: update the relevant sections of domain-context.md
   - If no changes: skip (don't touch the file)

2. **domain-terms.md** — Check if new domain terminology was introduced:
   - New entity types, status values, or business concepts?
   - Terms the spec-writer or dev-agent had to clarify during implementation?
   - If any new terms: append them to domain-terms.md with definitions
   - If no new terms: skip

3. **CLAUDE.md** — Check if project-level instructions need updating:
   - New build/test/lint commands introduced?
   - New conventions established during implementation?
   - New environment variables or configuration required?
   - If any: suggest updates to user (don't modify CLAUDE.md without user approval)

4. **Auto-memory** — Save non-obvious learnings to memory system:
   - Surprising constraints or gotchas discovered during implementation
   - Key architectural decisions and their rationale (the "why", not the "what")
   - Patterns that future features in this area should follow
   - Only save what can't be derived by reading the code or git history

Mark Knowledge Capture complete.

---

## Phase 9: Summary

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

### Knowledge Updates
- domain-context.md: [updated / no changes]
- domain-terms.md: [updated / no changes]
- CLAUDE.md: [suggestions made / no changes]
- Memory: [what was saved, if anything]

### Key Decisions
- [decisions made during implementation]

### Follow-up Items
- [anything deferred or noted for future work]
```

3. Remove `.sdlc/.enforce-worktree` flag file (deactivates enforcement)
4. Ask user: "Create PR with commit-commands?" If yes:
   ```
   Use /commit-commands:commit-push-pr to create branch, commit, push, and open PR
   ```

Mark Summary complete.
