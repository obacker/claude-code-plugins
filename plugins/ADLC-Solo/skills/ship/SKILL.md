---
name: ship
description: Pre-commit gate. Runs the verification suite and a reviewer pass on the diff, then reports whether the change is safe to commit.
disable-model-invocation: true
---

# Ship

Run before committing anything non-trivial.

## Step 1: Verification

Run every command in the `post_slice` section of `verification.yml`.
Record command, exit code, and a one-line output summary.

```
| Gate | Command | Result |
|------|---------|--------|
```

Any non-zero exit stops here. Report the exact output. Do not fix it inside
this skill; go back to `feature` or `bugfix`.

## Step 2: Review

Skip this step only if the diff is a single file under roughly 20 lines and
touches nothing sensitive.

Spawn the `reviewer` agent. Pass it: the diff range, the intent of the change,
and the acceptance criteria if there were any.

## Step 3: Verdict

```
## Ship check

Verification: PASS | FAIL
Review: PASS | PASS_WITH_CONCERNS | FAIL ([N] critical, [M] warning)

Verdict: SHIP | FIX FIRST
[if FIX FIRST: the specific items, in order]
```

## Rules

- Never modify any file inside this skill. Not production code, not tests,
  not config. Report and stop.
- Do not re-run the reviewer on unchanged code after a fix; scope it to the
  files that changed.
