# Upgrading ADLC Solo

## How upgrades work

**Plugin binary** (agents, skills, hooks inside the plugin): auto-updated by Claude Code
when `autoUpdate: true` is set in your marketplace config. No action needed.

**Scaffold files** (files written into your project by `adlc-init`): these are generated
once and become part of your project. The plugin cannot auto-update them — changes must
be applied manually.

This file documents what to do when scaffold files change between versions.

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
