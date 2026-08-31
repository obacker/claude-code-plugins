# Upgrading ADLC Solo

## How upgrades work

**Plugin binary** (agents, skills, hooks inside the plugin): auto-updated by Claude Code
when `autoUpdate: true` is set in your marketplace config. No action needed.

**Scaffold files** (files written into your project by `adlc-init`): these are generated
once and become part of your project. The plugin cannot auto-update them — changes must
be applied manually.

This file documents what to do when scaffold files change between versions.

---

## v2.2.x → v2.3.0

### 1. Check whether you actually have a `.claude/settings.json` (most projects: no)

`adlc-init` has been failing to write this file since v2.1.0 for every detected
stack (Go, TypeScript, JavaScript, Python, Rust). A `sed` collided with a
literal pipe in the substituted command, and `set -e` killed the run at that
point. So the `env` block v2.1.0 promised almost certainly never landed in your
project, even though the release notes said it did.

```bash
cat .claude/settings.json
```

Missing or empty → regenerate it:

```bash
adlc-init
```

`adlc-init` skips files that already exist, so this is safe to run in an
initialized project. It will create only what is missing.

If the file exists but has no `env` block, add one:

```json
{
  "env": {
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "75",
    "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "16000"
  }
}
```

### 2. If you use Claude Code cloud sessions: vendor the plugin

Cloud sessions (claude.ai/code) load hooks from your repo's
`.claude/settings.json`, but do NOT reliably load user-level installed plugins.
Without vendoring, none of the ADLC hooks, agents or skills are active in cloud.

```bash
adlc-init --vendor
git add .claude
git commit -m "chore: vendor ADLC for cloud sessions"
```

This copies `agents/`, `skills/` and `hooks/` into `.claude/` and merges hook
entries into `.claude/settings.json` using repo-relative paths.
`${CLAUDE_PLUGIN_ROOT}` does not resolve for a vendored copy, which is why the
paths differ from the plugin's own `hooks.json`.

The merge preserves your existing keys and hook entries and dedupes by command
string, so re-running it after a plugin update is safe and idempotent. Re-run it
on every plugin upgrade — the vendored copy is a snapshot and does not
auto-update.

Local-only projects need nothing here.

### 3. Nothing is required for the new guards

The Bash write guard is registered automatically. It respects the same
`.sdlc/.enforce-worktree` opt-in you already have; if you never created that
flag, nothing changes for you.

The two new guards are off by default:

| Want it? | Do this |
|----------|---------|
| Migration rollback enforcement | `touch .sdlc/.enforce-migrations` **and** add a `migrations:` block to `verification.yml` — the guard is inert without both |
| Test lock during bugfix | nothing — the `bugfix` skill sets and clears `.sdlc/.bugfix-active` itself |

The `migrations:` block is optional and is not written by `adlc-init`. The
verification.yml schema is otherwise unchanged:

```yaml
migrations:
  dir: "db/migrations"
  up_suffix: ".up.sql"
  down_suffix: ".down.sql"
```

### 4. If a bugfix ever aborts, check for a stale flag

`.sdlc/.bugfix-active` makes existing test files read-only. The `bugfix` skill
removes it on every exit path, but if a session is killed mid-bugfix the flag
can survive and silently block test edits in the next session.

```bash
ls -a .sdlc/ | grep bugfix-active && rm .sdlc/.bugfix-active
```

### 5. Optional: stop committing runtime state

Root-level `.sdlc/` is runtime state (agent log, context snapshots, enforcement
flags), not source. If your project commits it:

```bash
git rm -r --cached .sdlc
printf '/.sdlc/\n' >> .gitignore
```

### Behavior change to be aware of

Writing production code through Bash from the main checkout is now denied when
`.sdlc/.enforce-worktree` is set. If you had workflows relying on
`cat > src/foo.go` from the main checkout, they will now be blocked — that was
the bypass this release closes. Use a worktree, or remove the flag.

---

## v2.1.x → v2.2.0

### What changed

`scaffold/CLAUDE.md` gained a new `### AI Collaboration Principles` section
naming 4 behavioral principles (think before coding, simplicity first, surgical
changes, define success criteria). Agent prompts got a compact echo of the
same block.

### Action required: update your project's CLAUDE.md

Find the `### Key Rules` section in your project's `CLAUDE.md`. **Immediately
after** the numbered list ends (after rule 9 "Knowledge capture"), insert:

```markdown
### AI Collaboration Principles

The AI is the hands; the human is the architect. Move fast, but never faster than the human can verify.

1. **Think before coding** — State assumptions out loud. If intent is ambiguous, stop and ask; never guess. When multiple approaches exist, surface the trade-offs — do not silently pick one.
2. **Simplicity first** — Write the minimum code that solves the stated problem. No extra features, config knobs, or abstractions that weren't requested. 50 lines beats 200 lines if both work.
3. **Surgical changes** — Only touch code that must change. Do not reformat, re-comment, or "improve" unrelated code. Do not delete legacy code unless asked. Clean up only what you just introduced.
4. **Define success criteria** — Work in a loop against explicit, user-agreed criteria. Do not declare done until verification gates pass and the criteria are met.
```

No changes needed to `.sdlc/`, `verification.yml`, or hooks — the agent
prompts inside the plugin carry the same principles automatically after
`/plugin update`.

### Or: re-run adlc-init

If your `CLAUDE.md` is unmodified from the original scaffold, regenerate it:

```bash
adlc-init --force
```

**Warning:** `--force` overwrites — back up customizations first.

---

## v2.0.x → v2.1.0

### What changed

`adlc-init` now writes an `env` block into `.claude/settings.json` with two performance
env vars. Previously these were documented in `CLAUDE.md` but never actually set.

### Action required: existing projects

Add the `env` block to your project's `.claude/settings.json`:

```json
{
  "env": {
    "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE": "75",
    "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "16000"
  },
  "hooks": {
    ...existing hooks...
  }
}
```

**Safe to apply:** Claude Code deep-merges project-level `env` with your global
`~/.claude/settings.json` env. Your global vars (`CLAUDE_CODE_SUBAGENT_MODEL`,
`CLAUDE_CODE_EFFORT_LEVEL`, etc.) are unaffected.

### Action required: update CLAUDE.md

In your project's `CLAUDE.md`, find the `### Performance Configuration` section and
replace it:

**Before (remove this):**
```
Environment variables for token optimization:
- `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=75`
- `CLAUDE_CODE_MAX_OUTPUT_TOKENS=16000`
- `MAX_THINKING_TOKENS=8000`
```

**After (use this):**
```
Token optimization env vars are pre-configured in `.claude/settings.json`:
- `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=75` — compact at 75% of context window
- `CLAUDE_CODE_MAX_OUTPUT_TOKENS=16000` — cap output token usage

These merge with global `~/.claude/settings.json` env vars (deep-merge, no replacement).
```

Note: `MAX_THINKING_TOKENS` was removed — it is not a real Claude Code env var.

### Or: re-run adlc-init

If you haven't customized `CLAUDE.md` or `.claude/settings.json`, you can regenerate them:

```bash
adlc-init --force
```

**Warning:** `--force` overwrites existing scaffold files. Only use this if you haven't
made custom edits to `CLAUDE.md`, `.claude/settings.json`, `verification.yml`,
`domain-context.md`, or `domain-terms.md`. Back up any customizations first.

---

## General upgrade checklist

When a new ADLC Solo version is released, check CHANGELOG.md for entries that mention
scaffold file changes. The affected files will be one or more of:

| File | Purpose | Safe to re-generate? |
|------|---------|----------------------|
| `CLAUDE.md` | Project rules and ADLC instructions | Only if not customized |
| `.claude/settings.json` | Project-level hooks and env vars | Only if not customized |
| `verification.yml` | Build/test commands for verification gates | Only if not customized |
| `domain-context.md` | Business domain description | No — contains your content |
| `domain-terms.md` | Domain vocabulary | No — contains your content |

For files marked "No — contains your content", apply the diff manually by checking
the scaffold source in the plugin's `scaffold/` directory.

---

## Finding the scaffold source

The canonical scaffold files are in the plugin directory. To see what the current
scaffold looks like:

```bash
# Find the plugin directory
ls ~/.claude/plugins/

# View current scaffold
cat ~/.claude/plugins/adlc-solo*/scaffold/settings.json
cat ~/.claude/plugins/adlc-solo*/scaffold/CLAUDE.md
```

Compare against your project files and apply any differences that are relevant.
