---
name: review-slice
description: Post-slice validation — cross-checks feature-registry, runs verification gates, produces coverage report. Use after a slice is implemented.
argument-hint: Milestone ID and slice number (e.g., "M001 slice-1")
---

# ADLC Review Slice

Validate that a completed slice meets all acceptance criteria and verification gates.

## Prerequisites

- Slice implementation is complete (all dev-agents returned)
- feature-registry.json has been updated by dev-agents

## Process

### Step 1: Feature Registry Cross-Check

Read `.sdlc/milestones/[MILESTONE-ID]/feature-registry.json`

For each AC:
1. Check `passes` field
2. If `passes: true`:
   - Grep codebase for test function name
   - Test file must exist
   - Test must not be skipped, commented out, or marked pending
   - Run the specific test — must actually pass
3. If `passes: false`:
   - Check if this AC was in scope for this slice
   - If in scope: this is a GAP — flag it
   - If not in scope: expected, note for future slices

Produce registry validation table:
```
| AC ID | Registry | Test Exists | Test Passes | Status |
|-------|----------|-------------|-------------|--------|
| AC1   | true     | yes         | yes         | OK     |
| AC2   | true     | yes         | NO          | MISMATCH |
| AC3   | false    | n/a         | n/a         | PENDING (slice 2) |
```

### Step 2: Verification Gates

Run commands from verification.yml `post_slice` section:
```bash
# For each command in post_slice:
# Execute, capture exit code and output
# Record: command, pass/fail, output summary
```

Gate results:
```
| Gate | Command | Result | Notes |
|------|---------|--------|-------|
| Build | npm run build | PASS | |
| Lint | npm run lint | PASS | |
| Test | npm test | PASS | 47/47 tests |
| Coverage | npm run coverage | WARN | 78% (target 80%) |
```

### Step 3: Code Quality Summary

If pr-review-toolkit was run during build-feature:
- Summarize findings by severity
- Note which were fixed vs deferred

If not run yet:
- Recommend running pr-review-toolkit before merge

### Step 4: Report

Present consolidated report to user:
```
## Slice Review: [Milestone] / Slice [N]

### Registry Status
[table from Step 1]
Mismatches: [count] | Gaps: [count]

### Verification Gates
[table from Step 2]
All gates passed: [yes/no]

### Recommendation
[PASS / PASS_WITH_GAPS / FAIL]

[If FAIL: specific items to fix before proceeding]
[If PASS_WITH_GAPS: what remains for future slices]
```

## Rules

- Run ALL verification commands — don't skip any
- **NEVER modify ANY files during review** — not production code, not test files, not config
- The enforce-worktree hook blocks production code edits, but test files are allowed for QA agents — review-slice is NOT a QA agent and must NOT write test files
- If a mismatch is found: report it, don't fix it
- If gates fail: report exact output, don't attempt to fix
- If you feel the urge to "quickly fix" something: STOP. That's the dev-agent's job in the next cycle.

## Anti-Rationalization List (Review)

- "Just a small test fix" → No. Report it. Dev-agent fixes it.
- "The test is obviously wrong, let me correct it" → Report with evidence. You don't modify.
- "I'll save time by fixing while reviewing" → Mixing review and fix produces bad reviews AND bad fixes.
- "It's just a typo in a test name" → Report it. Discipline matters more than convenience.
