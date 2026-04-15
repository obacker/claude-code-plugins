---
name: shared-write-ui-tests
description: "Generate Playwright UI tests from BDD scenarios. Shared by DEV (happy path) and QA (edge cases). Trigger: 'UI tests for [FEAT-ID]', 'Playwright tests', 'behavior tests', 'e2e tests'."
---

<context>
You plan UI tests from BDD acceptance criteria, then spawn an agent in a worktree to write them. DEV mode = happy path, QA mode = edge cases. You do NOT write test code yourself in main conversation.

CRITICAL: The enforce-worktree hook will DENY test file edits from main conversation. You MUST spawn an agent.
</context>

<instructions>

## Phase 1 — Plan tests (you do this in main conversation)

Read:
- `.sdlc/specs/[FEAT-ID]-*-spec.md` — acceptance criteria
- Existing test files — avoid duplicating tests
- `.sdlc/domain-terms.md` — use correct terminology

Ask the user:
- **DEV mode** (happy path): Tests for the GREEN path of each AC
- **QA mode** (edge cases): Tests for error states, empty states, boundary inputs, concurrent actions

Plan the test list:
```
Tests to write:
1. [FEAT-ID] AC-001: [happy path behavior]
2. [FEAT-ID] AC-002: [happy path behavior]
3. [FEAT-ID] Edge: [error state]
...
```

## Phase 2 — Spawn agent to write tests (MANDATORY)

Choose agent based on mode:
- **DEV mode** → spawn dev-agent (model: sonnet, isolation: worktree)
- **QA mode** → spawn qa-agent (model: sonnet, isolation: worktree)

```
Spawn Agent:
  type: dev-agent (DEV mode) or qa-agent (QA mode)
  model: sonnet
  prompt: |
    Write Playwright UI tests for [FEAT-ID].

    ## Tests to write
    [paste planned test list from Phase 1]

    ## Selector strategy (priority order)
    1. data-testid attributes (preferred)
    2. ARIA roles: page.getByRole('button', { name: 'Submit' })
    3. Text content: page.getByText('Welcome')
    4. NEVER use CSS selectors, XPath, or DOM structure

    ## File
    tests/e2e/[FEAT-ID].spec.ts (or match existing convention)
```

## Phase 3 — Review results (you do this in main conversation)

After agent completes:
1. Read the test results
2. If data-testid attributes are needed, note them for DEV
3. Verify registry was updated

</instructions>

<documents>
- `.sdlc/specs/[FEAT-ID]-*-spec.md`
- `.sdlc/domain-terms.md`
- Existing test files in project
</documents>
