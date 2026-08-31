---
name: bugfix
description: Fix a bug by finding the root cause first, proving it with a failing test, then fixing it. Use for defects, errors, crashes, and wrong behaviour.
disable-model-invocation: true
---

# Bugfix

## Step 1: Root cause, before any fix

1. Read the error or report in full.
2. Reproduce it. Find or write the command or test that triggers it.
   If you cannot reproduce it, gather evidence; do not guess.
3. `git log --oneline -20`: did something recent cause this?
4. Trace backward from the failure: what threw, what called it, what data
   flowed in.
5. Find working code that does something similar. What differs?
6. State ONE hypothesis, out loud, with its evidence:

   ```
   Hypothesis: [specific cause] because [specific evidence]
   ```

Do not proceed without this line.

## Step 2: Lock the tests

Create `.sdlc/.bugfix-active`. This activates the hook that makes existing
test files read-only. Creating a NEW test file stays allowed; that is the
RED step.

Remove the flag on **every** exit path, including aborts. A leftover flag
silently blocks test edits in the next session.

## Step 3: RED

Write a new failing test named for the defect. Run it. Confirm it fails for
the reason your hypothesis predicts. If it fails for a different reason, your
hypothesis is wrong; go back to step 1.

## Step 4: GREEN

Fix it. Change as little as possible. Run the new test, then the full suite.

## Step 5: Verify and close

1. Run all `post_task` commands from `verification.yml`.
2. Remove `.sdlc/.bugfix-active`. Confirm it is gone.
3. If the bug exposed something non-obvious about the system, add it to
   `domain-context.md`. If terminology confusion contributed, fix
   `domain-terms.md`. If neither, write nothing.
4. Commit: `fix(scope): what was wrong and why`.

For anything touching money, auth, or migrations, run `ship` before committing.

## Rules

- Never fix by editing or skipping an existing test. If a test is genuinely
  wrong, that is a spec change: stop and say so.
- If three fix attempts fail, question the hypothesis rather than attempting
  a fourth fix.
