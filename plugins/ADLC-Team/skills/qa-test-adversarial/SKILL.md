---
name: qa-test-adversarial
description: "Run adversarial tests against a feature — edge cases, security, boundary attacks, business logic attacks. Trigger: 'adversarial tests for [FEAT-ID]', 'security test', 'edge case testing'. Available to QA role."
---

<context>
You are the orchestrator for adversarial testing. Your job is to plan the attack vectors, then spawn a qa-agent in a worktree to execute them. You do NOT write tests yourself in main conversation.

CRITICAL: The pretooluse-guard hook will DENY test file edits from main conversation. You MUST spawn a qa-agent.
</context>

<instructions>

## Phase 1 — Plan attack vectors (you do this in main conversation)

Read:
- `.sdlc/specs/[FEAT-ID]-*-spec.md` — what was specified
- `.sdlc/specs/[FEAT-ID]-registry.json` — what DEV claims passes
- Source code for the feature (use Grep to find relevant files)
- Existing tests (to understand what's already covered)

For each AC, plan attacks across these categories:

**Input attacks:** null, empty, whitespace, 10K+ strings, special chars (`<script>`, SQL injection, path traversal `../`), unicode, emoji, negative numbers, zero, MAX_INT, float precision

**Auth/access attacks:** missing token, expired token, wrong role, deleted user

**State attacks:** race conditions, stale data, partial failures, replay attacks

**Business logic attacks:** boundary values, impossible sequences, negative quantities, self-referential data

## Phase 2 — Spawn qa-agent to execute (MANDATORY)

You MUST spawn a qa-agent. Do NOT write test code yourself.

```
Spawn Agent:
  type: qa-agent
  model: sonnet
  prompt: |
    Run adversarial tests for [FEAT-ID].

    ## Feature spec
    [paste relevant ACs from spec]

    ## Attack vectors to execute
    [paste your planned attack vectors from Phase 1]

    ## Output
    Write report to .sdlc/reviews/[FEAT-ID]-adversarial-report.md
```

The qa-agent definition handles test rules, evidence standards, severity classification, and report format.

## Phase 3 — Post results (you do this in main conversation)

After qa-agent completes, read the report and post to GitHub:

```bash
gh issue comment [SPEC_ISSUE] --body "## QA: Adversarial test report — [FEAT-ID]
**Tests:** [N] total, [N] passed, [N] failed
**Critical findings:** [count]
**Verdict:** [PASS/FAIL]
**Full report:** .sdlc/reviews/[FEAT-ID]-adversarial-report.md"
```

If FAIL with critical findings:
```bash
gh issue edit [SPEC_ISSUE] --add-label "adlc:qa-failed"
```

If PASS:
```bash
gh issue edit [SPEC_ISSUE] --remove-label "adlc:ready-for-qa" --add-label "adlc:qa-passed"
```

## QA failure rework path

When QA fails a feature:
1. QA posts detailed findings on the spec issue with `adlc:qa-failed` label
2. DEV picks up the issue in next smart-start DEV session (it appears under "Blocked")
3. DEV fixes issues, runs verification, removes `adlc:qa-failed` and adds `adlc:ready-for-qa`
4. QA re-tests in next smart-start QA session (it appears under "Failed QA, needs re-test")

</instructions>

<documents>
- `.sdlc/specs/[FEAT-ID]-*-spec.md`
- `.sdlc/specs/[FEAT-ID]-registry.json`
- `.sdlc/reviews/` — output directory
</documents>
