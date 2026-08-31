# Changelog

## v3.0.0 (2026-08-31)

A deliberate simplification. v2.3.0 was designed in April 2026 and encoded
workarounds for platform gaps that no longer exist: plan mode, the built-in
`Explore` and `Plan` subagents, native compaction and checkpointing, and
`/rewind` now cover what the plugin was hand-rolling.

### Breaking: skills removed

`/adlc:build-feature`, `/adlc:plan-milestone`, `/adlc:plan-slice`,
`/adlc:review-slice`, `/adlc:explore`, `/adlc:start-session` and `/adlc:adlc`
are removed. Use `/adlc:feature`, `/adlc:bugfix`, `/adlc:ship`.

### Breaking: BDD spec artifacts removed

`milestone-spec.md` and `feature-registry.json` are no longer produced or read.
Existing files under `.sdlc/milestones/` are ignored, not migrated, and not
deleted. `adlc-init` no longer creates `.sdlc/milestones/`.

The `spec-writer` agent that produced them is gone. It wrote BDD acceptance
criteria plus a registry whose purpose was to let agents prove compliance to
each other; a solo developer has nobody to prove to.

### Breaking: worktree isolation and spec immutability enforcement removed

`enforce-worktree.py` and `protect-spec.py` are deleted. `.sdlc/.enforce-worktree`
has no effect; delete the flag file from any project that has one.

Worktree enforcement was the single largest drag on solo speed. With the flag
set, every production-code edit outside a worktree was denied, so a one-line fix
cost a full agent spawn plus worktree setup.

### Breaking: agents removed

`spec-writer`, `dev-agent` and `qa-spec-checker` are deleted. `qa-adversarial`
is renamed and rewritten as `reviewer`. A new project-level `Explore` agent
overrides the built-in and pins it to haiku; since v2.1.198 the built-in
inherits the main conversation's model, so exploration on an Opus session is
expensive.

`dev-agent` was the largest token sink. The main session writing code directly
is faster, and `/rewind` covers rollback.

### Changed: TDD is conditional

Test-first applies to money, invoicing, tax, auth, permissions, and database
migrations. Everything else does not need it. In v2.3.0 it was the "TDD iron
law", universal and unconditional.

### Changed: subagents no longer load CLAUDE.md

`load-claude-md: false` on both agents. `scaffold/CLAUDE.md` was being
re-injected into every subagent spawn at 1344 tokens.

### Changed: all skills are user-invoked only

`disable-model-invocation: true` on all three skills. `build-feature` was a
3153-token body that triggered an agent chain; it must never fire because the
user's sentence happened to contain the word "add".

### Changed: hooks reduced from 9 registrations to 2

Kept: `guard-test-lock.py` (the one failure mode a stronger model does not
self-correct: weakening a test until it passes) and `guard-migrations.py`
(migrations are the changes `/rewind` cannot undo). Both now cover
`Edit|Write|Bash` and both stay opt-in behind their flag files.

Dropped: `protect-spec.py`, `enforce-worktree.py`, `guard-bash-write.py` as a
separate entry (both surviving guards already handle the Bash path through
`_adlc_bashparse`), `post-edit-compile-check.py` (belongs in the project's own
`.claude/settings.json`, where `adlc-init` already scaffolds it),
`on-agent-stop.sh`, `save-context.sh` and `_harvest_discoveries.py`.

`_adlc_paths.py` loses `is_exempt_from_worktree`, `is_in_worktree`,
`is_spec_file` and `is_spec_approved_for_file`. `hook-matrix.sh` drops the
worktree and spec-protection cases and covers the two surviving guards on both
the Edit and Bash paths; 43 cases, all passing.

### Measured token effect

Measured with tiktoken `cl100k_base`.

| Item | v2.3.0 | v3.0.0 |
|---|---|---|
| `scaffold/CLAUDE.md`, re-injected into every subagent spawn | 1344 | 346 |
| Always-on plugin metadata (skill and agent names plus descriptions, plus the plugin description) | 485 | 230 |
| Per-spawn context floor (CLAUDE.md + domain-context + domain-terms + verification.yml) | 2167 | 1169 |
| One feature run, 5 dev tasks: system prompt and context floor before any real work | 32506 | not applicable; there is no agent chain |

The always-on metadata was never the problem. The orchestration was: a single
feature spawned 6 to 11 agents, each paying the per-spawn floor, and Anthropic
documents multi-agent workflows at roughly 4x to 7x the tokens of a
single-agent session. The per-feature system-prompt and context floor drops
from roughly 32500 tokens to under 3500 for a medium feature, because the
default path is now "main session does the work" rather than "orchestrator
spawns a chain".

### Files

35 files to 21.

## v2.3.0 (2026-08-31)

### Fix: Bash write bypass (critical)

Both PreToolUse hooks were registered with matcher `"Edit|Write"` only. A file
written through the **Bash** tool never reached them, so worktree isolation and
spec immutability were bypassable with `cat > f`, `tee`, `sed -i`, `>>`, `cp`,
`dd`, or `python -c`. The README claimed "Platform (hook blocks the action)"
for both; that claim was false on the Bash path.

**New hook scripts:**

- `hooks/scripts/guard-bash-write.py` — registered for matcher `"Bash"`. Parses
  the command for write constructs, resolves the destinations, and applies the
  same two rules the Edit/Write guards apply.
- `hooks/scripts/_adlc_bashparse.py` — the command parser. Fails open by
  design: a destination it cannot resolve confidently produces no target, and a
  command with no targets is allowed. Targets built from variables, command
  substitution, or process substitution are deliberately not resolved.
- `hooks/scripts/_adlc_paths.py` — the exemption predicates (`.sdlc/`, `.md`,
  test/spec/mock/fixture, worktree detection, approved-spec lookup), shared so
  the Edit/Write and Bash guards cannot drift apart.

`enforce-worktree.py` now imports those predicates, with an inline fallback so a
missing module degrades to the previous behavior rather than failing.

**Gating:** worktree isolation stays opt-in behind `.sdlc/.enforce-worktree`.
Approved-spec immutability is NOT flag-gated on the Bash path, mirroring
`protect-spec.py` which is likewise unconditional — gating it would have left
the bypass open on every project that has not opted into worktrees.

### Add: `adlc-init --vendor`

Copies `agents/`, `skills/` and `hooks/` into the project's `.claude/` and
merges hook entries into `.claude/settings.json` with `${CLAUDE_PLUGIN_ROOT}`
rewritten to repo-relative paths (that variable does not resolve for a vendored
copy).

This is what makes ADLC work in Claude Code cloud sessions. Cloud sessions DO
load and fire hooks from the repo's `.claude/settings.json`, but do NOT reliably
load user-level installed plugins — `~/.claude/settings.json` does not exist
there. Vendoring is the reliable distribution path for cloud.

The merge preserves unrelated top-level keys and existing hook entries, and
dedupes by command string, so re-running adds nothing. A `settings.json` that is
not valid JSON is left untouched rather than overwritten.

### Fix: `adlc-init` never wrote `.claude/settings.json`

Pre-existing since v2.1.0. The `sed` filling `scaffold/settings.json` used
`s|{{POST_EDIT_CHECK}}|$POST_EDIT_CHECK|g`, but the substituted value contains a
literal pipe (`go vet ./... 2>&1 | head -20`), which collides with sed's
delimiter. `sed` aborted, `set -e` killed the script, and the file was never
written — for Go, TypeScript, JavaScript, Python and Rust projects, i.e. every
detected stack.

The `env` block introduced in v2.1.0 (`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`,
`CLAUDE_CODE_MAX_OUTPUT_TOKENS`) therefore never reached those projects, despite
the v2.1.0 notes saying it did. Substitution now goes through `python3`, which
the plugin already requires. Verified rc=0 with a valid `settings.json` and the
env block present on all four stacks.

### Add: two opt-in PreToolUse guards

Both are inert until you create the flag file, both fail open, and both use the
same exemption logic as the worktree guard.

- `hooks/scripts/guard-migrations.py` — activates on `.sdlc/.enforce-migrations`.
  Denies creating a NEW up-migration under the configured directory unless the
  matching down artifact is written by the same operation or already exists.
  The directory and the up/down suffixes are read from `verification.yml`
  (`.sdlc/verification.yml` first, then the project root); with no `migrations:`
  block the guard is inert. **The verification.yml schema is unchanged** — the
  block is optional and is not written by `adlc-init`.
- `hooks/scripts/guard-test-lock.py` — activates on `.sdlc/.bugfix-active`.
  Denies edits to test files that already exist; creating a NEW test file stays
  allowed, so the RED step still works. The `bugfix` skill creates the flag in
  Phase 0 and removes it in Phase 5 and on both abort paths (Phase 3 BLOCKED,
  Phase 4 FAIL), which previously exited without any teardown.

### Add: absorbed from ADLC-Team

- `SessionEnd` trigger for `save-context.sh` (was `PreCompact` only).
- Async discovery harvest in `on-agent-stop.sh`: the `## Discoveries` section of
  the agent's report is appended to `.sdlc/_active/CAPTURES.md` by a forked and
  disowned subshell, so the hook returns immediately (measured 69ms).

Nothing else was taken from Team. Team's `pretooluse-guard.sh` is broken in
three ways — its `*/.sdlc/*` fast path makes the spec-approval block below it
unreachable, it ignores the `.enforce-worktree` opt-in, and it denies test files
from the main checkout, blocking the RED step of TDD. Solo's Python hooks are
correct on all three and were not replaced.

### Fix: README enforcement claims

- The enforcement table now has a **matcher coverage** column stating exactly
  which tools each hook intercepts. No row claims platform-level blocking on a
  path it does not cover.
- New "Known gaps" section stating plainly what the Bash parser does not
  resolve, and that the Bash path is narrower than the Edit/Write path.
- The Commands table listed eight `/adlc:*` commands. There is no `commands/`
  directory in this plugin; they are skills. Replaced with a Skills table using
  the correct `/adlc-solo:*` invocation.

### Add: cloud-safety guidance in skills and agents

Audited every skill and agent. No `gh` invocations and no `&&`-chained git
commands existed, so nothing needed repair; guidance was added to keep it that
way:

- `agents/dev-agent.md`: new "Cloud-Safe Git" section — one git invocation per
  Bash call (the cloud auto-mode classifier rejects
  `git add && git commit && git push`), and `gh` is not installed in cloud.
- `skills/build-feature/SKILL.md`: the PR step now checks `command -v gh` first
  and degrades with a clear message instead of failing.

### Add: `tests/hook-matrix.sh`

Builds a throwaway git repo with an approved spec (`spec_approved_at` set) and a
real worktree, feeds real JSON on stdin to every registered PreToolUse guard,
and asserts 48 allow/deny rows. All matching strips whitespace first, so
`json.dumps`' `": "` and `printf`'s `":"` both match and assertions cannot
silently pass on formatting. Exits non-zero on any mismatch.

### Hygiene

- `.gitignore`: root-level `/.sdlc/` is now ignored; `.sdlc/agent-log.txt` was
  committed and has been removed from the index.
- `plugin.json` and `.claude-plugin/marketplace.json` both at `2.3.0`.
- Fixed pre-existing marketplace drift for `adlc-team` (7.3.0 → 7.4.0, matching
  its `plugin.json`). No other ADLC-Team file was touched.

## v2.2.0 (2026-04-18)

### Add: AI Collaboration Principles (Karpathy-style)

Names the behavioral expectations the ADLC mechanics already assume but never
stated explicitly. The principles target common AI-coding failure modes:
silent assumptions, over-engineering, unrelated refactors, no stopping point.

**Principles:**
1. **Think before coding** — state assumptions; ask when unclear; surface trade-offs rather than pick silently.
2. **Simplicity first** — minimum code only; no unrequested flexibility or abstractions.
3. **Surgical changes** — only touch what must change; no drive-by refactors/reformats.
4. **Define success criteria** — loop against explicit criteria; verification gates must pass before "done".

**Changes:**

- `scaffold/CLAUDE.md`: new `### AI Collaboration Principles` section, placed between `Key Rules` and `Session Discipline` (100 → 101 lines).
- `agents/spec-writer.md`, `agents/dev-agent.md`, `agents/qa-spec-checker.md`, `agents/qa-adversarial.md`: short `## Collaboration Principles` block at the top of each agent's instructions with a pointer back to the scaffold CLAUDE.md for the full wording.
- `.claude-plugin/marketplace.json`: `adlc-solo` entry catches up from `2.0.1` to `2.2.0` (previous drift).

**Impact:** New projects get the principles automatically. Existing projects
must copy the new section into their `CLAUDE.md` manually — see
[UPGRADING.md](UPGRADING.md).

## v2.1.0 (2026-04-11)

### Fix: Performance env vars now actually set in project settings

`scaffold/CLAUDE.md` documented three env vars under "Performance Configuration" but
`scaffold/settings.json` had no `env` block — so `adlc-init` never set them. The
documentation was aspirational, not operational.

**Changes:**

- `scaffold/settings.json`: added `env` block with two confirmed env vars:
  - `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=75` — compact at 75% of context window
  - `CLAUDE_CODE_MAX_OUTPUT_TOKENS=16000` — cap output token usage
- `scaffold/CLAUDE.md`: removed `MAX_THINKING_TOKENS=8000` (not a real env var — absent
  from the Claude Code binary); updated Performance Configuration section to state that
  these are auto-configured by `adlc-init`, not manually managed.

**Impact:** New projects initialized with `adlc-init` automatically get the correct
`.claude/settings.json` `env` block. Existing projects must add the block manually —
see [UPGRADING.md](UPGRADING.md).

**Merge safety:** Project-level `env` in `.claude/settings.json` is deep-merged with
global `~/.claude/settings.json` env, so global vars (e.g. `CLAUDE_CODE_SUBAGENT_MODEL`,
`CLAUDE_CODE_EFFORT_LEVEL`) are unaffected.

## v2.0.1 (2026-04-11)

- fix: chỉ rõ `subagent_type: adlc-solo:*` trong skills — tránh lỗi "Agent type not found"
- fix: xóa fields `skills/hooks/agents` khỏi plugin.json — validator không chấp nhận

## v2.0.0 (2026-04-10)

Based on Claude Code Insights analysis (1,434 messages, 172 sessions, 24 days).

### Convention Fixes
- Agent frontmatter: `tools` field converted to YAML arrays (all 4 agents)
- plugin.json: `agents` as explicit file path array, added `author.url`
- hooks.json: `statusMessage` added to all 5 hook entries

### Friction Elimination (M1)
- enforce-worktree.py: blocks production code edits on ALL branches (was main/master only)
- New PostToolUse compile-check hook: auto `go vet` / `tsc --noEmit` after source file edits
- dev-agent: anti-drift rules (turn 10/15 progress gates), context discipline, coverage gate (85%)
- Tighter turn budgets: dev-agent 50→35, qa agents 20-25 (was 50)
- scaffold/CLAUDE.md: 7 new sections from Insights (session discipline, process compliance, agent isolation, language conventions, deployment, performance config, project-level hooks)

### Agent Reliability (M2)
- on-agent-stop.sh: warnings surfaced to stdout (was log-only)
- build-feature: auto-retry on tool-limit/merge-conflict failures (max 2 retries)
- build-feature: reads .sdlc/agent-log.txt after each agent return

### QA Agent Split (platform-enforced model routing)
- Replaced single qa-tester with qa-spec-checker (model: haiku, 20 turns) + qa-adversarial (model: sonnet, 25 turns)
- Models in agent frontmatter = platform-enforced, not instruction-level

### Task Sizing
- plan-slice: sizing guide table aligned to 35-turn budget (max 3 files, 1-2 ACs per task)
- build-feature Phase 3: explicit 35-turn budget in decomposition rules

### Advanced Automation (M3)
- New /adlc meta-skill: smart router that auto-detects project state
- build-feature: state machine gates with verification commands at every phase transition

### Project-Level Hooks (M1-T3)
- New scaffold/settings.json: PostToolUse + PreCompact hooks for ALL Claude Code sessions
- adlc-init: auto-generates .claude/settings.json with stack-specific compile commands

## v12.0.1 (2026-04-08)

### Turn Budget Fixes
- dev-agent: maxTurns 40 → 50, added graceful degradation (commits partial work + reports remaining ACs via DONE_WITH_CONCERNS when nearing budget)
- qa-tester: maxTurns 30 → 50, switched Mode 1 to batch-first strategy (run full suite before drilling down), added scoped adversarial fallback when budget is tight
- build-feature: DONE_WITH_CONCERNS handler now detects "remaining ACs" case and re-spawns new dev-agent for uncovered work
- spec-writer: unchanged at 30 (sufficient headroom)

### Docs
- Fixed README: qa-tester runs in main tree, not worktree

## v12.0.0 (2026-04-07)

Complete redesign from v11. ~74% code reduction (3900 → ~1000 lines).

### Architecture Changes
- Converted from 5-agent architecture to 3-agent + companion plugins
- Replaced orchestrator agent with `build-feature` command skill (feature-dev pattern)
- Replaced review-agent with `pr-review-toolkit` companion plugin (6 specialized agents)
- Replaced context-keeper skill with `claude-md-management` companion plugin
- Replaced progress-sync skill with `github` companion plugin
- Removed deploy-engineer skill (project-specific, not ADLC's scope)

### Enforcement Upgrades (prose → platform)
- Tool restrictions: `disallowedTools` / `tools:` in frontmatter (was prose instructions)
- Worktree isolation: `isolation: worktree` in frontmatter (was prose + hook validation)
- Model routing: `model:` in frontmatter (was prose instructions)
- Turn limits: `maxTurns:` in frontmatter (was custom budget tracking)
- Spec immutability: `protect-spec.py` PreToolUse hook (was prose-only rule)

### New Features (from Superpowers patterns)
- Two-stage review: spec compliance THEN code quality (ordered, not parallel)
- Model routing by task complexity: Haiku (simple) → Sonnet (moderate) → Opus (complex)
- TDD iron law with anti-rationalization lists in dev-agent
- Implementer status protocol: DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED
- Verification-before-completion: fresh test output required, no trust of cached claims
- Systematic debugging 4-phase in bugfix skill

### Removed
- agent-registry.json and per-agent state.json (replaced by agent memory + git)
- 3-tier persistence model (replaced by git + memory + feature-registry)
- on-session-start.sh crash recovery (replaced by agent memory)
- on-session-end.sh timestamp tracking (not needed)
- Budget tracking (replaced by maxTurns)
- CONNECTORS.md (replaced by plugin.json companionPlugins)
- AGENTS.md template (merged into CLAUDE.md)

### Setup
- One-command install via plugin system
- `adlc-init` script auto-detects stack and generates scaffold
- 5-minute setup (was 30-60 minutes)
