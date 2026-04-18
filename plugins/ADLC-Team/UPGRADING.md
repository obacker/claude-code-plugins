# UPGRADING — ADLC-Team

## v7.2 → v7.3

Adds the **AI Collaboration Principles** block (4 principles: think before coding, simplicity first, surgical changes, define success criteria) to scaffold `CLAUDE.md` and all 3 agent prompts. Backward-compatible, no mechanical changes.

### Update the plugin

```bash
/plugin update adlc-team@obacker-claude-code-plugins
```

Agents (`ba-agent`, `dev-agent`, `qa-agent`) get the principles automatically on update — they live inside the plugin. The only manual action is updating your project's `CLAUDE.md`.

### Action required: update your project's CLAUDE.md

Find the `### Key rules` section. **Immediately after** the numbered list (after rule 6 "GitHub Issues"), insert:

```markdown
### AI Collaboration Principles

The AI is the hands; the human is the architect. Move fast, but never faster than the human can verify.

1. **Think before coding** — State assumptions out loud. If intent is ambiguous, stop and ask; never guess. When multiple approaches exist, surface the trade-offs — do not silently pick one.
2. **Simplicity first** — Write the minimum code that solves the stated problem. No extra features, config knobs, or abstractions that weren't requested. 50 lines beats 200 lines if both work.
3. **Surgical changes** — Only touch code that must change. Do not reformat, re-comment, or "improve" unrelated code. Do not delete legacy code unless asked. Clean up only what you just introduced.
4. **Define success criteria** — Work in a loop against explicit, user-agreed criteria. Do not declare done until verification gates pass and the criteria are met.
```

No changes to `.sdlc/`, hooks, verification.yml, or skills.

### Rollback

Revert the plugin to `7.2.0` in your marketplace pin; remove the `### AI Collaboration Principles` section from your project's `CLAUDE.md`.

---

## v7.1 → v7.2

Driven by team feedback: RAM spikes, 20-min hangs, token waste (especially in DEV skills). Full optimization rationale: `Misc/ADLC-Team-Optimization-Plan.md`.

### Update the plugin

```bash
/plugin update adlc-team@obacker-claude-code-plugins
```

### Changes that affect you (backward-compatible)

**Nothing in `.sdlc/` needs editing.** Existing specs, registries, task files, and progress files continue to work.

**Files kept for 30 days as rollback**:
- `hooks/scripts/protect-spec.py.bak`
- `hooks/scripts/enforce-worktree.py.bak`

If you see unexpected behavior from `pretooluse-guard.sh`, edit `hooks/hooks.json` to point back at the `.bak` scripts while you file an issue.

### New capabilities you can start using

- **`dev-cost-report` skill** — run weekly. Produces `.sdlc/reports/cost-report-[YYYY-WW].md`.
- **Advisor escalation pattern** — Orchestrator and agents all run on Sonnet. `dev-agent` and `ba-agent` bodies instruct the agent to exit `DONE_WITH_CONCERNS` with tag `needs-orchestrator-advisor` on architectural decisions, multi-file churn, spec ambiguity, or after a failed verification retry. The Sonnet orchestrator then calls its built-in `advisor` tool (which reaches a stronger Opus reviewer) before respawning. This is an instruction-level pattern — no frontmatter change. (The optimization plan's draft `advisor:` YAML block was not a real Claude Code field; it has been removed.)
- **Project-level hooks** — copy `plugins/ADLC-Team/scaffold/.claude/hooks-project-example.json` to your repo's `.claude/hooks.json` and adjust the lint/typecheck commands.

### Behavior changes you will notice

- **Agent turn limits are lower** (dev 40→30, qa/ba 30→25). Dev-agents return `DONE_WITH_CONCERNS` earlier for long tasks — the orchestrator auto-continues. If a task keeps needing continuation, split it smaller in `dev-split-tasks`.
- **Max 2 dev-agents in parallel.** A third independent task queues. Adjust mental model: less simultaneous fan-out, same throughput in practice.
- **PR review is sequential.** `code-reviewer` runs first, then `pr-test-analyzer` reads its output. Expect ~2× the wall-clock time but ~50% of the peak RAM.
- **Spawn prompts pass task file *path*, not content.** If you customized a local skill to paste task bodies inline, remove that — dev-agents now read task files themselves.
- **Mandatory Haiku routing** for simple tasks (renames, stubs, formatting, single-line config, dep bumps). Check `spawn-patterns.md` for the exact list.
- **10-minute timeout on every agent spawn.** A HUNG agent is force-killed and three recovery options are offered (split / haiku / escalate).

### Verification after upgrade

- [ ] `gh issue` + `git worktree` still work inside the hook path (try one dev-agent spawn on a throwaway branch)
- [ ] `pretooluse-guard.sh` allows edits under `.sdlc/` and denies edits to a non-worktree production file
- [ ] `compile-check.sh` runs without failing agent calls (its warnings go to stderr, it never blocks)
- [ ] A parallel spawn of 3 independent tasks queues the third (observable in progress file)

### Rollback

Edit `hooks/hooks.json` to replace the single `pretooluse-guard.sh` entry with the old two-Python-script block (see git history of this file or the `.bak` scripts). Roll `plugin.json` version back to `7.1.0`.
