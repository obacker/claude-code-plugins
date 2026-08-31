# ADLC Solo v3 - lightweight lifecycle for one developer

Three skills, two agents, two hooks. The main session writes the code; the
process gets out of the way except where a mistake is expensive.

## What's new in v3.0.0

v2.3.0 was designed in April 2026 and encoded workarounds for platform gaps
that no longer exist. v3 removes them.

| | v2.3.0 | v3.0.0 |
|---|---|---|
| Skills | 8 | 3 (`feature`, `bugfix`, `ship`) |
| Agents | 4 | 2 (`reviewer`, `Explore`) |
| Hook registrations | 9 | 2 |
| Hook scripts | 11 | 4 |
| `scaffold/CLAUDE.md` | 1344 tokens | 346 tokens |
| TDD | universal | conditional: money, auth, migrations |
| BDD spec artifacts | `milestone-spec.md`, `feature-registry.json` | none |
| Worktree isolation | opt-in, enforced by hook | removed |

The default path is now "main session does the work" rather than "orchestrator
spawns a chain". A single feature used to spawn 6 to 11 agents, each paying a
2167 token context floor.

**Breaking.** `/adlc:build-feature`, `/adlc:plan-milestone`, `/adlc:plan-slice`,
`/adlc:review-slice`, `/adlc:explore`, `/adlc:start-session` and `/adlc:adlc`
are gone. See [UPGRADING.md](UPGRADING.md).

## What it does

1. **Spec-lite** - 5 to 15 lines: intent, acceptance, constraints, out of scope.
   Shown for a yes, not written to a file.
2. **Route by risk** - money, auth, permissions, migrations, or user-data
   deletion means plan mode plus test-first. Anything else in 1 or 2 files just
   gets done. Three or more files gets plan mode without the test-first rule.
3. **Verification loop** - the commands in `verification.yml` run after each
   meaningful change, not once at the end.
4. **Ship** - the pre-commit gate: verification suite, then a `reviewer` pass on
   the diff, then a SHIP or FIX FIRST verdict.

## Install

```bash
# Install ADLC Solo
/plugin install adlc-solo@obacker-claude-code-plugins

# Optional companions
/plugin install pr-review-toolkit@claude-plugins-official
/plugin install commit-commands@claude-plugins-official
/plugin install context7@claude-plugins-official
/plugin install github@claude-plugins-official

# Install LSP for your stack
/plugin install typescript-lsp@claude-plugins-official  # or pyright-lsp, gopls-lsp, etc.

# Initialize in your project
adlc-init

# Or, for Claude Code cloud sessions (claude.ai/code) - vendors the plugin
# into .claude/ so cloud actually loads it. Commit .claude/ afterwards.
adlc-init --vendor
```

### Local vs cloud

| | Local Claude Code | Cloud (claude.ai/code) |
|---|---|---|
| Repo `.claude/settings.json` hooks | loaded | loaded |
| User-level installed plugins | loaded | **not reliably loaded** |
| What to run | `adlc-init` | `adlc-init --vendor`, then commit `.claude/` |

## Skills

This plugin ships **skills**, not slash commands; there is no `commands/`
directory. All three are user-invoked only (`disable-model-invocation: true`),
so a heavyweight workflow never fires because your sentence contained the word
"add".

| Skill | Invoke as | Description |
|-------|-----------|-------------|
| `feature` | `/adlc-solo:feature` | Spec-lite, plan-mode gate by risk, verification loop |
| `bugfix` | `/adlc-solo:bugfix` | Root cause first, then RED, then GREEN |
| `ship` | `/adlc-solo:ship` | Pre-commit gate: verification suite plus reviewer pass |

## Architecture

```
2 agents:  reviewer (sonnet)  reads the diff, reports findings by severity,
                              never edits production code
           Explore  (haiku)   read-only search; overrides the built-in so
                              exploration does not inherit an Opus session

3 skills:  feature, bugfix, ship

2 hooks:   guard-test-lock  (PreToolUse: Edit|Write|Bash)
           guard-migrations (PreToolUse: Edit|Write|Bash)
```

There are exactly two gates:

1. **Plan mode**, before implementation, for anything risky or spanning three
   or more files. You approve the plan before code is written.
2. **`ship`**, before commit. Verification suite plus a reviewer pass on the
   diff. A CRITICAL finding blocks the commit.

Everything between those two gates is the main session writing code and running
the verification commands. No spawn, no worktree, no registry.

## Key Enforcement

Two PreToolUse hooks remain, both registered for `Edit|Write|Bash`. Both are
opt-in behind a flag file and inert without it.

| What | Hook | Matcher coverage | Level |
|------|------|------------------|-------|
| Existing tests locked during a bugfix | `guard-test-lock.py` PreToolUse | `Edit`, `Write`, `Bash` | Platform (hook denies the call). Opt-in via `.sdlc/.bugfix-active`, set by the `bugfix` skill |
| Migration needs a rollback artifact | `guard-migrations.py` PreToolUse | `Edit`, `Write`, `Bash` | Platform (hook denies the call). Opt-in via `.sdlc/.enforce-migrations`, inert unless configured in `verification.yml` |
| Tool restrictions | `tools:` in agent frontmatter | agent spawn | Platform (enforced) |
| Model routing | `model:` in agent frontmatter | agent spawn | Platform (enforced) |
| Skills never auto-fire | `disable-model-invocation: true` | skill listing | Platform (enforced) |
| Agents skip CLAUDE.md | `load-claude-md: false` | agent spawn | Platform (enforced) |
| Verification gates | `verification.yml` commands | - | Command (exit code) |

Only two survive because the model does self-correct the rest. These two guard
the failure modes it does not: weakening a test until it passes, and a
migration that `/rewind` cannot undo.

### What the platform now handles instead

| Removed from the plugin | Native replacement |
|---|---|
| `skills/explore` | Built-in `Explore` subagent: read-only, skips CLAUDE.md and git status |
| `skills/plan-milestone`, `skills/plan-slice` | Plan mode plus the built-in `Plan` subagent |
| `skills/adlc` router | The model routes on skill descriptions |
| `skills/start-session`, `save-context.sh` | Native compaction, memory, and checkpointing that persists across sessions |
| Manual rollback discipline | `/rewind` checkpointing (Esc Esc) |
| `enforce-worktree.py`, `protect-spec.py` | Nothing. Both are deliberately gone; see UPGRADING.md |
| `post-edit-compile-check.py` | The project's own `.claude/settings.json`, already scaffolded by `adlc-init` |
| Turn budgets, anti-drift gates, anti-rationalization lists | Current models do not need them, and hard-coded process scaffolding is a documented anti-pattern |

### Known gaps

Both guards parse the Bash command line for write constructs: `>`, `>>`,
heredoc-into-file, `tee`, `sed -i`, `cp`/`mv`, `dd of=`, and `python -c` with
an `open(..., "w")`. They **fail open by design**: a destination they cannot
resolve confidently is allowed, not denied, because a false denial costs more
than the residual gap. Specifically they do not resolve:

- targets built from variables or command substitution (`> $F`, `> $(mktemp)`)
- process substitution (`> >(tee f)`)
- writes performed inside a script the command invokes
- writes by a compiled binary or an interpreter reading from a file

So the Bash path is **narrower than the Edit/Write path**, which sees the
resolved destination directly. Treat it as closing the common bypasses, not as
an airtight boundary.

Run `bash tests/hook-matrix.sh` to see the exact allow/deny decision for every
covered case.

### Opt-in enforcement flags

Both flag-gated guards are off until you create the flag file, and go inert
again when you remove it.

| Flag file | Activates | Extra requirement |
|-----------|-----------|-------------------|
| `.sdlc/.enforce-migrations` | A new up-migration needs a matching down artifact | a `migrations:` block in `verification.yml`, otherwise inert |
| `.sdlc/.bugfix-active` | Existing test files are read-only; new test files still allowed | set and cleared by the `bugfix` skill |

The migrations block is optional and is **not** written by `adlc-init`. Add it
yourself when you want the guard:

```yaml
migrations:
  dir: "db/migrations"
  up_suffix: ".up.sql"
  down_suffix: ".down.sql"
```

## When to reach for more process

v3 is deliberately thin. Add process back only on evidence, and add back the
one thing that failed, not all of it.

- **The change touches money, invoicing, tax, auth, permissions, or a
  migration.** Use the sensitive path in `feature`: a failing test, committed
  on its own, before the implementation. This is not optional, and "it is slow"
  is not a reason to skip it.
- **The same instruction has to be repeated three or more times in a week.**
  That is a real skill waiting to be written. Write it then, not before.
- **Quality drops on the specific class of task where a gate was removed.**
  That gate was load-bearing. Restore that one.
- **The model violates a convention it used to follow.** Check whether the
  convention lived in the part of `scaffold/CLAUDE.md` that v3 cut. If so, it
  belongs in the Conventions section, in one line.

## Companion Plugin Roles

All optional in v3.

- **pr-review-toolkit**: specialized code review agents, if you want more than
  the built-in `reviewer`
- **commit-commands**: tool-restricted git operations
- **context7**: live API and library documentation during development
- **github**: GitHub issues, PRs, Projects integration
- **LSP**: code intelligence (go-to-definition, diagnostics, type checking)

## Requirements

- Claude Code with plugin support
- Git initialized project
- Python 3.x (for hook scripts)
- Bash (for shell hooks)

## Tests

```bash
bash tests/hook-matrix.sh
```

Builds a throwaway git repo, feeds real hook JSON on stdin to both registered
PreToolUse guards, and asserts the allow/deny decision for 43 cases. Exits
non-zero on any mismatch.

## Upgrading

The plugin itself auto-updates if `autoUpdate: true` is set in your marketplace config.
However, **scaffold files in your projects are not auto-updated**; they are generated
once by `adlc-init` and owned by your project after that.

When a new release changes scaffold files, you need to manually apply those changes to
existing projects. See [UPGRADING.md](UPGRADING.md) for per-release instructions.

### Quick reference

| From -> To | Action required |
|-----------|-----------------|
| any -> v2.1.0 | Add `env` block to `.claude/settings.json` (see UPGRADING.md) |
| v2.1.x -> v2.2.0 | Copy `AI Collaboration Principles` section into your project's `CLAUDE.md` (see UPGRADING.md) |
| v2.2.x -> v2.3.0 | Re-run `adlc-init` (or `adlc-init --vendor` for cloud); re-check `.claude/settings.json` exists (see UPGRADING.md) |
| v2.x -> v3.0.0 | Commands renamed; delete `.sdlc/.enforce-worktree`; optionally shrink your `CLAUDE.md` (see UPGRADING.md) |

## License

MIT - oBacker (obacker.com)
