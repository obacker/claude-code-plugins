---
name: dev-adversarial-fix
description: "Use when DEV has finished implementing a feature and wants to self-test adversarially before submitting to QA — proactively finds and fixes edge case, security, and boundary bugs. Trigger: 'pre-QA check', 'adversarial self-test', 'tự test trước khi nộp QA', 'find and fix before QA'."
---

<context>
You are the orchestrator for DEV-side adversarial self-testing. Your job: plan attack vectors from the spec, spawn agents to do the actual work. You do NOT read source code, write tests, or edit production code yourself.

CRITICAL: The pretooluse-guard hook will DENY code edits from main conversation. You MUST spawn agents.

This skill SKIPS spec compliance check — DEV already verified all ACs pass via TDD. Focus ONLY on adversarial discovery.
</context>

<instructions>

## Bước 0 — Hỏi user

Hỏi: **"Bạn muốn kiểm tra task/spec nào? (nhập FEAT-ID)"**

STOP. Chờ user trả lời. Sau đó dùng FEAT-ID đó cho tất cả các bước phía dưới.

## Phase 1 — Classify and plan (you do this in main conversation)

Read ONLY `.sdlc/specs/[FEAT-ID]-*-spec.md`. Do NOT read source code or test files — agents will do that.

**Step 1a — Classify feature type** (determines which attack categories to run):

| Feature has... | Run these categories |
|---|---|
| Write operations (create/update/delete) | Input attacks + Business logic attacks |
| Auth / roles / permissions | + Auth/access attacks |
| File, path, or URL handling | + Path traversal from Input attacks |
| Concurrent operations or background jobs | + State attacks |
| Read-only / display only | Input attacks only |

**Step 1b — Plan specific attack vectors** for selected categories only:

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
    Focus ONLY on these attack categories: [list selected categories from Phase 1]

    ## Attack vectors to execute
    [paste your planned attack vectors from Phase 1b]

    ## Early exit rule
    If you find 3 or more CRITICAL findings, write the report immediately and stop.
    Do not continue to remaining categories.

    ## Output
    Write report to .sdlc/reviews/[FEAT-ID]-adversarial-report.md
    For each finding include: severity, reproduction steps, exact test command that fails.
    Classify each finding: CRITICAL / HIGH / MEDIUM / LOW
```

## Phase 3 — Present findings and wait for user confirmation (you do this in main conversation)

Read `.sdlc/reviews/[FEAT-ID]-adversarial-report.md`.

Cross-reference findings against `.sdlc/specs/[FEAT-ID]-*-spec.md` (already in context from Phase 1):
- Nếu finding mâu thuẫn với spec (e.g. spec cho phép giá trị đó) → đánh dấu `[spec-conflict]`, không đưa vào danh sách fix
- Nếu finding hợp lệ → giữ nguyên

Present findings to the user in this format:

```
## Adversarial test results — [FEAT-ID]

**CRITICAL ([n])**
- [finding-id] [short description] — [one-line repro]

**HIGH ([n])**
- [finding-id] [short description] — [one-line repro]

**MEDIUM/LOW ([n])** (will not be auto-fixed)
- [finding-id] [short description]

Proceed with fixing CRITICAL and HIGH findings? (yes / no / select specific IDs)
```

**STOP. Wait for user response before continuing.**

- User says **no** or there are no CRITICAL/HIGH → feature is ready for QA. Done.
- User says **yes** → proceed to Phase 4 with all CRITICAL/HIGH findings.
- User selects specific IDs → proceed to Phase 4 with only those findings.

## Phase 3b — Prepare fix branch (you do this in main conversation)

Trước khi fix, chạy:

```bash
git checkout -b fix/[FEAT-ID]-adversarial
git pull origin main
```

Đảm bảo branch mới, không fix trên main, và đã sync với origin để tránh conflict.

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

    When done, output a one-line summary per finding:
    FIXED: [finding-id] | [test file:line] | [command to verify]
```

Apply the **Timeout policy** from `../dev-implement/references/spawn-patterns.md` (10-minute wall-clock).

## Phase 5 — Targeted verify pass (MANDATORY)

After dev-agent completes with DONE, extract from its output:
- The exact test file paths it modified
- The exact verify commands per finding

Spawn ONE qa-agent with that targeted context — no exploration needed:

```
Spawn Agent:
  type: qa-agent
  model: haiku
  isolation: worktree
  prompt: |
    Verify adversarial fixes for [FEAT-ID]. Do NOT explore the codebase.

    Run these exact commands and report PASS/FAIL per finding:
    [paste the "FIXED: ..." lines from dev-agent output verbatim]

    SKIP spec compliance check. Stop after running all commands.
```

**If all PASS** → feature is ready for QA. Done.

**If any FAIL** → return to Phase 4 with only the failing findings. Max 1 re-loop.
If still failing after 2 loops, escalate to `dev-bugfix` for root cause analysis.

## Phase 6 — Hand off to QA

No GitHub labels or comments needed — this is a DEV-internal pre-QA step.
Leave the spec issue as-is. QA runs their own `qa-test-adversarial` as the independent final gate.

</instructions>

<documents>
- `.sdlc/specs/[FEAT-ID]-*-spec.md` — only file orchestrator reads
- `.sdlc/reviews/[FEAT-ID]-adversarial-report.md` — output from Phase 2
- `../dev-implement/references/spawn-patterns.md` — timeout policy
</documents>
