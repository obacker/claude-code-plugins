---
description: Lightweight bug fix with root-cause analysis — investigate, delegate fix to dev-agent in worktree, QA validation by qa-tester. No spec/milestone phases.
argument-hint: Bug description or error message
---

# ADLC Bugfix

Fix a bug using systematic root-cause analysis. Orchestrator investigates, dev-agent implements in worktree, qa-tester validates.

## Principles

- Root cause FIRST, fix SECOND — no exceptions
- Orchestrator investigates only — **never implement fixes directly**
- Dev-agent implements in isolated worktree — enforced
- QA validates after fix — mandatory, no exceptions

## Agent Roles

| Role | Who | Isolation | Model |
|------|-----|-----------|-------|
| Investigation | Orchestrator (you) | main | — |
| Implementation | dev-agent | worktree | sonnet |
| QA Validation | qa-tester | none | sonnet |
| Mechanical tasks | general-purpose agent | none | haiku |

## Model Routing

When spawning agents, choose the model based on task complexity:

- **Mechanical tasks** (add stubs, rename, format, fix imports): `model: haiku`
- **Implementation with judgment** (fix logic, refactor, write tests): `model: sonnet`
- **Architectural decisions** (redesign component, change API contract): `model: opus`

---

## Process

### Phase 0: Activate Enforcement

1. Create `.sdlc/` directory if it doesn't exist
2. Create `.sdlc/.enforce-worktree` flag file (activates the PreToolUse hook that blocks production code edits on main)
3. This flag is removed in Phase 5 after completion

### Phase 1: Root Cause Investigation (Orchestrator — you)

**NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.**

1. Read the bug description / error message completely
2. Reproduce the bug:
   - Find or write a command/test that triggers the error
   - If can't reproduce: gather more evidence, don't guess
3. Check recent changes: `git log --oneline -20` — did something change recently?
4. Trace data flow backward from the error:
   - What function threw? What called it? What data was passed?
   - Use Explore agents (haiku) for reading/searching if needed
5. Find a working example: is there similar code that works? What's different?
6. Form ONE hypothesis. Write it down explicitly:
   ```
   Hypothesis: [specific cause] because [evidence]
   ```

### Phase 2: Bugfix Report (Orchestrator — you)

Create `.sdlc/bugfix-[YYYYMMDD]-[short-id].md`:

```markdown
## Bug: [title]

### Hypothesis
[specific cause] because [evidence]

### Reproduction
[command or test that triggers the bug]

### Files Involved
- [file1]: [what's wrong]
- [file2]: [what's wrong]

### Expected Fix
[brief description of what needs to change]

### Failing Test
Name: `Test_Bugfix_[Component]_[Behavior]`
```

This report is the dev-agent's input. Writing it forces clear thinking.

### Phase 3: Fix (dev-agent — MANDATORY DELEGATION)

**DO NOT implement the fix yourself. You MUST spawn a dev-agent.**

1. Spawn **dev-agent** (`isolation: worktree`, `model: sonnet`):
   - Use the Agent tool with `subagent_type: general-purpose` and `isolation: worktree`
   - Pass the full bugfix report content as the prompt
   - Include: hypothesis, reproduction steps, files involved, expected test name
   - Dev-agent instructions:
     1. Write failing test `Test_Bugfix_[Component]_[Behavior]`
     2. Confirm test fails (reproduces the bug)
     3. Implement minimal fix — change as little as possible
     4. Confirm test passes
     5. Run ALL tests — no regressions
     6. Run post_task verification from verification.yml
     7. Commit: `fix([scope]): [description of what was wrong and why]`
     8. Report completion status: DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED

2. Wait for dev-agent completion
3. Handle dev-agent status:
   - **DONE**: proceed to Phase 4
   - **DONE_WITH_CONCERNS**: note concerns, proceed to Phase 4
   - **NEEDS_CONTEXT**: provide context, re-spawn dev-agent
   - **BLOCKED**: after 3 re-attempts → STOP, report to user:
     "Root cause may be different than hypothesized. Evidence: [...]"

### Phase 4: QA Validation (qa-tester — MANDATORY)

**DO NOT skip QA. You MUST spawn a qa-tester after dev-agent completes.**

1. Spawn **qa-tester** (`model: sonnet`, no isolation — needs to see merged code):
   - Use the Agent tool with `subagent_type: general-purpose`
   - Pass: bugfix report, dev-agent's changed files, what was fixed
   - qa-tester instructions:
     1. Run the bugfix test FRESH — must pass
     2. Run full test suite — no regressions
     3. Write 2-3 adversarial tests for the fixed code:
        - Edge case inputs related to the bug
        - Boundary values
        - Related failure scenarios
     4. Report: PASS / FAIL / PASS_WITH_CONCERNS with evidence

2. If qa-tester reports FAIL:
   - Re-spawn dev-agent with qa-tester's findings
   - Loop max 2 times. Still failing → report to user.

### Phase 5: Verify & Complete

1. Run ALL verification commands from verification.yml FRESH
2. Confirm: bugfix test passes, no regressions, QA passed
3. **Knowledge capture** — update project knowledge if the bug revealed something non-obvious:
   - **domain-context.md**: Did the bug expose an undocumented constraint, integration quirk, or architectural assumption? If yes, add it.
   - **domain-terms.md**: Did terminology confusion contribute to the bug? If yes, clarify the term.
   - **Auto-memory**: Save the root cause pattern if it's likely to recur (e.g., "timezone handling in X module assumes UTC but receives local time"). Skip if the fix is self-explanatory from the code.
   - If nothing non-obvious was learned: skip all updates (don't write for the sake of writing)
4. Remove `.sdlc/.enforce-worktree` flag file (deactivates enforcement)
5. Present bugfix report to user

## Anti-Rationalization List

- "Quick fix, investigate later" → You'll never investigate later. Do it now.
- "Obviously it's X" → If it were obvious, it wouldn't be a bug. Verify.
- "Just try this" → Random changes create random results. Hypothesize first.
- "Multiple things might be wrong" → Test one variable at a time.
- "I'll just fix it myself, faster than spawning an agent" → That's how enforcement breaks down. Delegate.
- "Too simple for a worktree" → Isolation is not about complexity. It's about safety and discipline.
- "Skip QA, tests already pass" → Tests passing ≠ fix is correct. QA finds what you missed.
- "Just one quick edit on main" → One exception becomes the norm. Use the worktree.

## Output

```
## Bugfix Report: [title]

### Root Cause
[What was wrong and why — 2-3 sentences]

### Hypothesis
[What you tested and evidence]

### Fix (dev-agent, worktree: [branch-name])
[What was changed — files and summary]

### QA (qa-tester)
- Result: PASS / FAIL / PASS_WITH_CONCERNS
- Adversarial tests added: [N]
- Findings: [summary]

### Verification
[All verification commands run, results shown]

### Knowledge Updates
- domain-context.md: [updated / no changes]
- domain-terms.md: [updated / no changes]
- Memory: [what was saved, or "nothing — fix is self-explanatory"]

### Commit
[commit hash]: fix([scope]): [message]
```

## Rules

- **Never implement fixes directly** — always delegate to dev-agent with `isolation: worktree`
- **Never skip QA** — always spawn qa-tester after dev-agent completes
- If the bug relates to an existing milestone: update feature-registry.json if relevant ACs were affected
- If the bug reveals a missing AC: note it but don't modify milestone-spec.md (suggest adding in next milestone)
- Never "fix" by disabling or skipping a test
- If fix attempt fails 3 times: STOP and question the hypothesis, not attempt fix #4
