---
name: feature
description: Build a feature with a short spec, a plan-mode gate for anything risky, and a verification loop. Use for new features and significant changes.
disable-model-invocation: true
---

# Feature

## Step 1: Spec-lite

Write 5 to 15 lines, no more:

```
Intent: [what the user can do after this that they cannot do now]
Acceptance:
  - [observable behaviour 1]
  - [observable behaviour 2]
Constraints: [what must not change; performance, compat, data]
Out of scope: [what you are deliberately not doing]
```

Show it. Get a yes. Do not create a file for it unless the user asks.

## Step 2: Route by risk

Check whether the change touches any of:

- money, invoicing, pricing, tax calculation
- auth, permissions, tenancy boundaries
- database migration or schema change
- deletion of user data

**If yes:** this is a sensitive change. Enter plan mode, present the plan, wait
for approval. Then follow "Sensitive path" below.

**If no, and the change is confined to 1 or 2 files:** just do it. No plan mode,
no agent, no ceremony.

**If no, but the change spans 3 or more files:** enter plan mode, present the
plan, wait for approval, then follow "Normal path".

## Normal path

1. Implement in the main session.
2. After each meaningful change, run the `post_task` commands from
   `verification.yml`. Fix what breaks before moving on.
3. When the change is complete, run `ship`.

## Sensitive path

1. Write a failing test that states the correct behaviour. Run it. Confirm RED.
2. Commit the test on its own, before implementing.
   Rationale: a committed test cannot be quietly weakened later to make an
   implementation pass.
3. Implement the minimum that turns it GREEN.
4. Repeat for each acceptance criterion.
5. Run `ship`.

The `.sdlc/.bugfix-active` flag locks existing test files. Set it during the
sensitive path if you want that protection, and remove it on every exit path.

## Rules

- Do not create `.sdlc/milestones/`, `milestone-spec.md`, or
  `feature-registry.json`. Those artifacts are gone in v3.
- Do not spawn a subagent to write code. The main session writes code.
- Spawn `Explore` when you need to find something across many files.
- If the user changes their mind mid-implementation, use `/rewind` rather
  than unwinding by hand.
