---
name: dev-adversarial-fix
description: "Use when DEV has finished implementing a feature and wants to self-test adversarially before submitting to QA — proactively finds and fixes edge case, security, and boundary bugs. Trigger: 'pre-QA check', 'adversarial self-test', 'tự test trước khi nộp QA', 'find and fix before QA'."
---

<context>
You are the orchestrator for DEV-side adversarial self-testing. Plan attack vectors, spawn a qa-agent to discover bugs, then spawn a dev-agent to fix them. You do NOT write test or production code yourself.

CRITICAL: The pretooluse-guard hook will DENY code edits from main conversation. You MUST spawn agents.

This skill SKIPS spec compliance check — DEV already verified all ACs pass via TDD. Focus ONLY on adversarial discovery.
</context>

<instructions>

## Phase 1 — Plan attack vectors (you do this in main conversation)

Read:
- `.sdlc/specs/[FEAT-ID]-*-spec.md` — what was specified
- Source code for the feature (use Grep to find relevant files)
- Existing tests (understand what's already covered — skip those attack angles)

For each AC, plan attacks across these categories:

**Input attacks:** null, empty, whitespace, 10K+ strings, special chars (`<script>`, SQL injection, path traversal `../`), unicode, emoji, negative numbers, zero, MAX_INT, float precision

**Auth/access attacks:** missing token, expired token, wrong role, deleted user

**State attacks:** race conditions, stale data, partial failures, replay attacks

**Business logic attacks:** boundary values, impossible sequences, negative quantities, self-referential data

## Phase 2 — Spawn qa-agent for adversarial discovery (MANDATORY)

You MUST spawn a qa-agent. Do NOT write test code yourself.

```
Spawn Agent:
  type: qa-agent
  model: sonnet
  prompt: |
    Run adversarial tests for [FEAT-ID].

    SKIP spec compliance check — DEV has already verified all ACs pass via TDD.
    Focus ONLY on adversarial testing.

    ## Attack vectors to execute
    [paste your planned attack vectors from Phase 1]

    ## Output
    Write report to .sdlc/reviews/[FEAT-ID]-adversarial-report.md
    Classify each finding: CRITICAL / HIGH / MEDIUM / LOW
```

## Phase 3 — Assess findings (you do this in main conversation)

Read `.sdlc/reviews/[FEAT-ID]-adversarial-report.md`.

- **No CRITICAL/HIGH findings** → skip to Phase 5, feature ready for QA
- **CRITICAL/HIGH findings exist** → continue to Phase 4

## Phase 4 — Spawn dev-agent to fix all findings (MANDATORY)

Batch ALL findings into ONE dev-agent spawn. Do NOT spawn separate agents per bug.

Model routing:
- All findings are input validation only (null, empty, boundary) → `model: haiku`
- Any auth, state, or business logic finding → `model: sonnet`

```
Spawn Agent:
  type: dev-agent
  model: [haiku | sonnet]
  isolation: worktree
  prompt: |
    Fix adversarial findings for [FEAT-ID].
    Adversarial report: .sdlc/reviews/[FEAT-ID]-adversarial-report.md

    Fix all CRITICAL and HIGH findings. For each:
    1. Write a failing test that reproduces the finding
    2. Fix the production code
    3. Verify the test passes

    Do NOT touch passing tests. Do NOT fix MEDIUM/LOW unless trivial.
    Commit prefix: fix([FEAT-ID]-adversarial)
```

Apply the **Timeout policy** from `../dev-implement/references/spawn-patterns.md` (10-minute wall-clock).

## Phase 5 — Single verify pass (MANDATORY)

After dev-agent completes with DONE, spawn ONE qa-agent to re-test all fixed vectors together.

```
Spawn Agent:
  type: qa-agent
  model: sonnet
  isolation: worktree
  prompt: |
    Verify adversarial fixes for [FEAT-ID].
    DEV fixed these findings: [list finding IDs + one-line fix summary from dev-agent report]

    Re-run ONLY the vectors that previously failed.
    SKIP spec compliance check.
    Report: PASS or FAIL with evidence per finding.
```

**If PASS** → feature is ready to submit for QA. Done.

**If FAIL** → return to Phase 4 with remaining failures. Max 1 re-loop. If still failing after 2 loops, escalate to `dev-bugfix` for root cause analysis.

## Phase 6 — Hand off to QA

No GitHub labels or comments needed — this is a DEV-internal pre-QA step.
Leave the spec issue as-is. QA will run their own `qa-test-adversarial` pass afterward as the independent final gate.

</instructions>

<documents>
- `.sdlc/specs/[FEAT-ID]-*-spec.md`
- `.sdlc/reviews/[FEAT-ID]-adversarial-report.md` — output
- `../dev-implement/references/spawn-patterns.md` — timeout policy, model routing
</documents>
