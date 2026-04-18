# ADLC-Team v7.2 Optimization Plan

**Date:** 2026-04-18
**Author:** Tuan + Claude (Co-founder AI)
**Scope:** Fix 3 pain points reported by team — RAM spike, 20-min hangs, token waste (esp. dev skills)
**Target version:** ADLC-Team v7.2 (from v7.1.0 baseline)
**Companion plan:** ADLC-Solo-Optimization-Plan.md (2026-04-10) — shared patterns apply

---

## 1. Team Feedback — Verbatim

> - Ngốn RAM
> - Đứng đơ tầm 20 phút
> - Vẫn còn tốn token, nhất là skill của dev

Team running v7.1.0 unpatched. No prior self-modifications. 5-person team (2 BA, 3 DEV, 1 QA) using the same plugin across multiple client repos.

---

## 2. Root Cause Analysis

### 2.1 "Đứng đơ 20 phút" — Hang diagnostics

| # | Root cause | Evidence | Likelihood |
|---|---|---|---|
| A | Orchestrator blocks on single dev-agent stuck near turn limit | `dev-agent.maxTurns=40`, TDD iron law + verification retry 2x → 2 TDD cycles easily burn 30-40 turns. No kill switch at orchestrator. | **High** |
| B | Python hook fork overhead on every Edit/Write | `protect-spec.py` + `enforce-worktree.py` = 2 Python cold starts (50-200ms each) + embedded git subprocess calls. 50 edits/session × 2 hooks = 5-20s cumulative lag, feels like hang. | **High** |
| C | Parallel worktree spawn stacking | `dev-implement` Step 4 allows unbounded parallel spawn. Large repos → git worktree create 3-10s each. 3 parallel = stacked IO wait. | **Medium** |
| D | SubagentStop hook runs synchronous find/grep per agent stop | `on-agent-stop.sh` scans `.sdlc/_active/` + greps KNOWLEDGE.md on every agent stop. Multiple concurrent agents stacked → 10s timeout × n. | **Medium** |
| E | Verification retry loop with no circuit breaker | dev-agent retries 2x on verification fail. If `npm test` hangs infinitely (flaky network, stuck port), dev-agent waits indefinitely within turn budget. | **Medium** |

### 2.2 "Ngốn RAM" — Memory profile

| # | Root cause | Evidence | Likelihood |
|---|---|---|---|
| F | Each worktree subagent holds independent context window | 3 parallel dev-agents × ~150K tokens effective = ~450K tokens active + main conversation + hook processes. No context sharing mechanism. | **High** |
| G | Long skills loaded in full when triggered | `dev-implement` 195 lines, `dev-split-tasks` 150 lines, `ba-write-spec` 131 lines, `shared-explore` 121 lines. No progressive disclosure — every bash template + markdown block is inline. | **High** |
| H | Full task file pasted into spawn prompts | `dev-implement` Step 4: `[paste full content of task-[NNN].md]`. Task files carry inline ACs + code snippets. Each parallel spawn duplicates the same context. | **Medium** |

### 2.3 "Tốn token, nhất là skill dev" — Waste breakdown

| # | Root cause | Location | Est. waste |
|---|---|---|---|
| I | Bash command duplication — 6 repetitions of `gh issue create/edit/comment` patterns | `dev-implement` Steps 2, 4, 5, 7 | ~40 lines × every load |
| J | Verbose spawn templates (15 lines) repeated across steps | `dev-implement` Step 4, Step 7, `dev-bugfix` Phase 2/3, `shared-write-ui-tests` Phase 2, `qa-test-adversarial` Phase 2 | 5 skills × 15 lines |
| K | Overlap between `dev-split-tasks` and `dev-implement` | Both read spec + verification.yml, both discuss slice planning | ~30 lines overlap |
| L | No Haiku routing enforcement for simple tasks | `dev-agent.md` defaults to sonnet; README mentions haiku but no gate in agent definition | Sonnet cost × N simple tasks (stubs/renames/formatting) |
| M | No Opus-advisor pattern (present in Solo v13 plan, absent here) | Missing advisor tool wiring in frontmatter | Course-correction waste when Sonnet picks wrong approach |
| N | Code review Step 7 spawns 2 parallel sonnet agents with fresh context | `dev-implement` Step 7 | ~300K tokens per PR review |

---

## 3. Optimization Roadmap

### 3.1 Targets

| Metric | Current (v7.1) | Target (v7.2) | Reduction |
|---|---|---|---|
| Max hang time | 20 min | 10 min (hard timeout) | 50% |
| Peak RAM with 3 parallel agents | ~450K tokens active | ~250K tokens | ~45% |
| dev-implement skill size | 195 lines inline | 80 lines + references | ~60% |
| Sonnet calls for simple tasks | 100% | ~40% (60% routed to Haiku) | ~60% cost |
| Python hook fork count per edit | 2 | 1 (bash consolidated) | 50% |

### 3.2 Priority tiers

- **P0** — Unblock team this week. Hooks + agent frontmatter + 1 skill edit. No structural refactor.
- **P1** — Structural refactor. Ship as v7.2 release. 1-2 weeks.
- **P2** — Nice-to-have. Schedule for v7.3 unless bundled convenient.

---

## 4. P0 — Emergency fixes (Week 1)

### P0-T1: Reduce agent turn limits

**File:** `plugins/ADLC-Team/agents/*.md`

| Agent | Current maxTurns | New maxTurns | Reason |
|---|---|---|---|
| `dev-agent` | 40 | **30** | 30 covers 2 TDD cycles + self-test + 1 retry. 40 invites turn-limit stalls. |
| `qa-agent` | 30 | **25** | Adversarial + spec compliance in 25. Force graceful DONE_WITH_CONCERNS earlier. |
| `ba-agent` | 30 | **25** | Spec writing doesn't need 30. Forces earlier `[PENDING]` marking. |

**Why:** Matches Solo v13 plan turn budget. Hitting the limit gracefully (reporting DONE_WITH_CONCERNS) is cheaper than stalling at the limit.

### P0-T2: Orchestrator-level timeout & circuit breaker

**File:** `plugins/ADLC-Team/skills/dev-implement/SKILL.md` — Step 4 addition
**File:** `plugins/ADLC-Team/skills/dev-bugfix/SKILL.md` — Phase 2 addition

Add instruction block to every agent spawn in skills:

```
## Timeout policy (MANDATORY)

When spawning a dev-agent or qa-agent, apply a 10-minute wall-clock timeout.
If no status report after 10 minutes:
1. Mark agent as HUNG — post GitHub Issue comment with `adlc:blocked`
2. Kill the worktree (`git worktree remove --force agent/<branch>`)
3. Report to user: "Agent hung at turn [N]/[maxTurns] on [file/command]"
4. Offer 3 choices: (a) split task smaller + respawn, (b) switch to Haiku, (c) skip + escalate
```

**Why:** 20-min hangs currently have no recovery path. Team manually Ctrl+C and loses all work. Circuit breaker caps worst-case loss at 10 min.

### P0-T3: Consolidate Python hooks into single bash wrapper

**File:** `plugins/ADLC-Team/hooks/scripts/pretooluse-guard.sh` (NEW)
**File:** `plugins/ADLC-Team/hooks/hooks.json` — update to call single script

Replace:
```json
"hooks": [
  {"type": "command", "command": "...protect-spec.py", "timeout": 5},
  {"type": "command", "command": "...enforce-worktree.py", "timeout": 5}
]
```

With:
```json
"hooks": [
  {"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/scripts/pretooluse-guard.sh", "timeout": 3}
]
```

The bash wrapper runs both checks in-process:
1. Fast path: if `file_path` is in `.sdlc/` or `.claude/` → allow immediately (no Python fork)
2. Spec check: inline bash test for `*-spec.md` + registry lookup (no Python)
3. Worktree check: single `git rev-parse` call (shared between checks)

**Why:** Eliminates 50% of fork overhead. Fast-path for ADLC artifacts (80% of orchestrator edits) avoids Python entirely. Keeps Python fallback for complex registry parsing only.

**Estimated effort:** 2 hours. Keep old `.py` scripts as `protect-spec.py.bak` for rollback.

### P0-T4: Hard cap parallel agent spawn

**File:** `plugins/ADLC-Team/skills/dev-implement/SKILL.md` — Step 3 + Step 4

Replace the current loose "can run in parallel" guidance with:

```
## Parallel execution limits

- Maximum 2 dev-agents spawned simultaneously
- If 3+ tasks have no dependency, queue them: spawn 2, wait for 1 to DONE, then spawn next
- Rationale: 3 parallel agents × 150K context = 450K peak tokens = RAM spike + IDE freeze on team machines
```

**Why:** Unlimited parallel spawn is the main RAM culprit. 2 agents give ~75% of parallelism benefit at ~50% of RAM cost.

### P0-T5: Enforce Haiku routing via agent definition

**File:** `plugins/ADLC-Team/agents/dev-agent.md`

Replace:
```yaml
model: sonnet
```

With explicit complexity-based routing documentation + spawn-time override guidance. Keep default as sonnet but add front-of-file instruction:

```yaml
model: sonnet    # orchestrator overrides to haiku for simple tasks (see dev-implement Step 4)
```

And in `dev-implement` Step 4, make Haiku routing mandatory (not optional) for these patterns:
- File rename / move only
- Add stub/skeleton (no logic)
- Formatting/linting fix
- Comment-only changes
- Single-line config value change
- Dependency version bump (no breaking change)

**Why:** v7.1 README mentions haiku but no skill actually routes to it. Team defaults to sonnet for everything. Explicit pattern list removes the judgment call.

---

## 5. P1 — Structural refactor (Weeks 2-3, ship as v7.2)

### P1-T1: Split dev-implement into orchestrator + references

**File:** `plugins/ADLC-Team/skills/dev-implement/SKILL.md` — slim to ~80 lines
**File:** `plugins/ADLC-Team/skills/dev-implement/references/github-ops.md` (NEW)
**File:** `plugins/ADLC-Team/skills/dev-implement/references/spawn-patterns.md` (NEW)

The skill loads only when triggered. Everything currently inline that is reference material moves to `references/*.md` which the orchestrator reads on-demand.

**Keep in SKILL.md (~80 lines):**
- Step 0 guard
- Step 1 state loading (3 file reads)
- Step 2-3 execution planning (high-level only)
- Step 4 spawn loop (short pseudo-code, reference spawn-patterns.md for template)
- Step 5-7 completion logic (short, reference github-ops.md for bash)

**Move to `references/github-ops.md`:**
- All `gh issue create/edit/comment` templates (currently 6 duplications)
- Label state machine table
- PR creation template

**Move to `references/spawn-patterns.md`:**
- Full "Spawn Agent:" templates for each scenario (dev-agent, qa-agent, pr-review-toolkit)
- Task content reference pattern (file path, not paste)

**Why:** 195 → 80 lines in hot path. Reference files only loaded when the specific step runs. Progressive disclosure pattern from the Solo plan.

### P1-T2: Task spawn via file reference, not paste

**File:** `plugins/ADLC-Team/skills/dev-implement/SKILL.md` Step 4
**File:** `plugins/ADLC-Team/agents/dev-agent.md`

**Before:**
```
prompt: |
  Implement [FEAT-ID]-T[NNN].
  ## Task
  [paste full content of task-[NNN].md]
```

**After:**
```
prompt: |
  Implement [FEAT-ID]-T[NNN].
  Task file: .sdlc/tasks/[FEAT-ID]/task-[NNN].md
  Registry: .sdlc/specs/[FEAT-ID]-registry.json
  Read both files first, then proceed with TDD.
```

Update `dev-agent.md` to instruct: "Read your task file first. It contains ACs, files, complexity, context."

**Why:** Task files are 50-200 lines each. Pasting into prompt duplicates content across parallel spawns. File reference = single source of truth, agent reads what it needs.

### P1-T3: Remove dev-split-tasks ↔ dev-implement overlap

**File:** `plugins/ADLC-Team/skills/dev-split-tasks/SKILL.md`
**File:** `plugins/ADLC-Team/skills/dev-implement/SKILL.md`

Shared read list (spec, verification.yml, domain-terms) moves to a shared section:

**File:** `plugins/ADLC-Team/skills/_shared/load-sdlc-context.md` (NEW)

Both skills reference it: "Run shared context load from `_shared/load-sdlc-context.md`."

**Why:** ~30 lines saved per skill. Single source of truth for "what DEV loads at start."

### P1-T4: Apply Opus-advisor pattern for complex decisions

**File:** `plugins/ADLC-Team/agents/dev-agent.md` — frontmatter
**File:** `plugins/ADLC-Team/agents/ba-agent.md` — frontmatter

Add advisor tool configuration (mirrors Solo v13):

```yaml
advisor:
  model: opus-4-6
  trigger: complexity-threshold
  when:
    - "architectural decision required"
    - "3+ files changed in single TDD cycle"
    - "spec ambiguity detected"
    - "verification gate failing after 1 retry"
```

**Why:** Sonnet main + Opus auto-escalate. Prevents "wrong approach" waste (Solo data: 29 incidents/month × 10-15 turns recovery each). Same pattern proven in Solo plan.

### P1-T5: PR review consolidation

**File:** `plugins/ADLC-Team/skills/dev-implement/SKILL.md` Step 7

Current Step 7 spawns 2 sonnet agents in parallel (code-reviewer + pr-test-analyzer) with fresh context.

**Change:** Spawn sequentially with shared context reference:

```
Step 7a: Spawn pr-review-toolkit:code-reviewer
         Reference: PR diff + spec path only (no full spec paste)
         Model: sonnet

Step 7b: Spawn pr-review-toolkit:pr-test-analyzer
         Reference: Step 7a output path + registry path
         Model: sonnet (haiku if diff <200 lines)
```

**Why:** Parallel spawn doubled RAM for sequential-tolerable work. Test analyzer benefits from reading code-reviewer output. Sequential with references keeps peak RAM low.

### P1-T6: Progressive disclosure for large skills

**Files:** All skills >100 lines
- `dev-split-tasks` (150 lines)
- `ba-write-spec` (131 lines)
- `shared-explore` (121 lines)

Pattern: Main SKILL.md keeps only:
1. Trigger + context
2. Step headers + 1-2 sentence purpose
3. One reference file per heavy step

Example for `ba-write-spec`:
- Keep: Steps 1-6 headers, self-review checklist (critical), output file paths
- Move to `references/spec-template.md`: Full markdown template (lines 42-77)
- Move to `references/registry-schema.md`: JSON schema (lines 78-89)

**Why:** Self-review checklist must stay inline (it's the quality gate). Templates can be referenced.

---

## 6. P2 — Nice-to-have (v7.3 or bundled with P1)

### P2-T1: Async KNOWLEDGE harvesting in SubagentStop

**File:** `plugins/ADLC-Team/hooks/scripts/on-agent-stop.sh`

Current: synchronous find + grep + sed on every agent stop (blocks 10s timeout).

**Change:** Fork background process for KNOWLEDGE harvest, exit 0 immediately:

```bash
# Existing validation (fast) stays synchronous
# KNOWLEDGE harvest forks to background
( harvest_knowledge "$INPUT" > /dev/null 2>&1 ) &
disown
exit 0
```

**Why:** Harvesting is non-blocking work. No one needs it completed before the next tool call.

### P2-T2: PostToolUse compile-check hook

**File:** `plugins/ADLC-Team/hooks/scripts/compile-check.sh` (NEW)
**File:** `plugins/ADLC-Team/hooks/hooks.json` — add PostToolUse entry

After each Edit/Write to source files:
- Go → `go vet ./...` on changed package
- TypeScript → `tsc --noEmit` on changed file
- Python → `python -c "import X"` for module sanity

If compile fails, append warning to agent context: "Compile check failed — review and fix before next TDD cycle."

**Why:** Catches buggy code 3-5 turns earlier. Same fix from Solo v13 plan M1-T2. Reduces "buggy code" waste (Solo: 31 incidents/month).

### P2-T3: Turn budget visibility

**File:** `plugins/ADLC-Team/agents/dev-agent.md`
**File:** `plugins/ADLC-Team/agents/qa-agent.md`

Add instruction: "At turn 10, 20, 25, report current progress and turn count as a single-line log: `TURN_STATUS: turn=20/30 acs_done=1/3 cycles_done=2`. This lets the orchestrator estimate completion."

**Why:** Currently orchestrator has zero visibility into subagent progress. Structured turn logs enable smarter timeout decisions (e.g., extend timeout if making progress).

### P2-T4: Project-level hook overrides

**File:** `plugins/ADLC-Team/scaffold/.claude/hooks-project-example.json` (NEW)

Provide a scaffold file teams can copy to their repo's `.claude/hooks.json` to add project-specific PostToolUse checks (lint, typecheck, contract tests). Documented in README.

**Why:** Different client projects have different stacks. Plugin provides framework, project overrides specifics.

### P2-T5: Cost dashboard skill

**File:** `plugins/ADLC-Team/skills/dev-cost-report/SKILL.md` (NEW)

New skill `dev-cost-report`: query session logs, report token usage per agent, flag sessions over budget. Run weekly by lead DEV.

**Why:** Team currently has no visibility into "is this workflow actually cheaper than without plugin?" Dashboard enables continuous optimization.

---

## 7. Changes by File — Implementation Spec

### 7.1 Files to modify

| File | P0 change | P1 change | P2 change |
|---|---|---|---|
| `agents/dev-agent.md` | maxTurns 40→30 | Add advisor config, task file reference | Turn status logging |
| `agents/qa-agent.md` | maxTurns 30→25 | — | Turn status logging |
| `agents/ba-agent.md` | maxTurns 30→25 | Add advisor config | — |
| `hooks/hooks.json` | Replace 2 Python with 1 bash | — | Add PostToolUse compile-check |
| `hooks/scripts/on-agent-stop.sh` | — | — | Async KNOWLEDGE harvest |
| `skills/dev-implement/SKILL.md` | Timeout, parallel cap, haiku routing | Split to 80 lines + references | — |
| `skills/dev-bugfix/SKILL.md` | Timeout policy | — | — |
| `skills/dev-split-tasks/SKILL.md` | — | Use shared load, reference pattern | — |
| `skills/ba-write-spec/SKILL.md` | — | Progressive disclosure | — |
| `skills/shared-explore/SKILL.md` | — | Progressive disclosure | — |
| `.claude-plugin/plugin.json` | version 7.1.0→7.2.0-beta | 7.2.0 | 7.2.1 |
| `README.md` | — | Update v7.2 changelog | — |

### 7.2 Files to create

| File | Priority | Purpose |
|---|---|---|
| `hooks/scripts/pretooluse-guard.sh` | P0 | Consolidated bash hook replacing 2 Python scripts |
| `skills/dev-implement/references/github-ops.md` | P1 | All `gh` CLI templates |
| `skills/dev-implement/references/spawn-patterns.md` | P1 | Agent spawn templates |
| `skills/_shared/load-sdlc-context.md` | P1 | Shared context-load instruction |
| `skills/ba-write-spec/references/spec-template.md` | P1 | Full spec markdown template |
| `skills/ba-write-spec/references/registry-schema.md` | P1 | Feature registry JSON schema |
| `hooks/scripts/compile-check.sh` | P2 | PostToolUse compile guard |
| `scaffold/.claude/hooks-project-example.json` | P2 | Project override example |
| `skills/dev-cost-report/SKILL.md` | P2 | Weekly cost audit |

### 7.3 Files to keep unchanged

- `bin/adlc-init` — init script unchanged
- `scaffold/*` (except new P2 file) — backward compatible
- `hooks/scripts/save-context.sh` — already lean
- Deprecated redirect skills (ba-start, dev-start, qa-start) — keep for backward compat

---

## 8. Success Metrics

Measure before rollout and 2 weeks after:

| Metric | Baseline (v7.1) | Target (v7.2) | How to measure |
|---|---|---|---|
| Average session hang events | Unknown (team reports "often") | <1/week | Agent log analysis |
| Max hang duration | 20 min | 10 min (hard cap) | Wall-clock timing in logs |
| Peak RAM per session | Unknown baseline | Measurable 30% drop | `ps aux` sampling during parallel spawn |
| Tokens per feature (BA + DEV + QA) | Unknown baseline | 25% reduction | Claude Code Insights report |
| Sonnet vs Haiku ratio for DEV tasks | ~95% sonnet | 60/40 sonnet/haiku | Model call logs |
| Agent turn-limit stalls | Unknown | <5/month | agent-log.txt WARN entries |
| Team satisfaction (NPS-style) | Current 3 complaints | No complaints in retro | Monthly retro |

---

## 9. Rollout Plan

### Phase 1 — P0 Emergency patches (Week of 2026-04-20)

- Day 1-2: Implement P0-T1 to P0-T5 on branch `v7.2-emergency`
- Day 3: Internal dogfood on oBacker's own claude-code-plugins repo
- Day 4: Release `v7.2.0-beta.1` to team. Monitor for 2 days.
- Day 5: Collect feedback, iterate.

### Phase 2 — P1 Structural (Weeks of 2026-04-27, 2026-05-04)

- Week 1: Implement P1-T1 to P1-T6 on branch `v7.2-structural`
- Week 2: Regression testing across all 3 roles. Fix bugs.
- End of week 2: Release `v7.2.0` stable.

### Phase 3 — P2 Enhancements (bundled into v7.2.1 or deferred)

- If P0 + P1 land on time: bundle P2-T1 (async harvest), P2-T2 (compile-check) into `v7.2.1`
- Defer P2-T3 to P2-T5 to v7.3 unless team specifically requests

### Rollback plan

- P0 patches keep old Python scripts as `.bak` for 30 days
- P1 version bump to 7.2.0 major-ish — document upgrade path in UPGRADING.md
- Each P1 skill refactor is independent — can revert per-skill if regression found

### Communication

- v7.2.0-beta.1 release note in team Slack #adlc channel
- 15-min walkthrough at Monday standup
- 2-week retrospective after stable release

---

## 10. Cross-Reference with ADLC-Solo Plan

Shared patterns applied from Solo v13 plan (2026-04-10):

| Solo v13 Pattern | Team v7.2 Application |
|---|---|
| Sonnet main + Opus advisor | P1-T4 (same advisor config) |
| Reduce turn budget | P0-T1 (dev 40→30, qa 30→25) |
| Compile-check hook | P2-T2 (same script shape) |
| Enforce-worktree fix | Not needed — Team version already covers all branches |
| Anti-drift instructions | Incorporated into P1-T1 skill slimming |
| Compaction threshold at 75% | Inherited from Claude Code settings — no Team-specific change |

Solo-specific patterns NOT applied to Team:
- Team already uses full worktree isolation (Solo had to add it)
- Team has multi-agent orchestration — different waste profile

---

## Appendix A — Token savings estimate

Rough estimate of token reduction per DEV session (feature implementation, ~20 turns, 3 agent spawns):

| Source | v7.1 tokens | v7.2 tokens | Saved |
|---|---|---|---|
| dev-implement skill load | ~8,000 | ~3,200 | 4,800 |
| 3 spawn prompts with task paste | ~15,000 | ~3,000 (references) | 12,000 |
| 2 PR review agent spawns | ~12,000 | ~6,000 (sequential, ref-based) | 6,000 |
| Hook fork overhead (Python→bash) | N/A (time, not tokens) | N/A | — |
| Duplicated GitHub ops templates | ~2,500 | ~800 | 1,700 |
| **Per session total** | **~37,500** | **~13,000** | **~24,500 (~65%)** |

Scales with parallel agent count. For a typical week (5 features × 3 agents each): ~367K tokens saved / week / team member.

---

## Appendix B — Validation checklist before v7.2.0 ship

- [ ] All P0 + P1 items implemented
- [ ] plugin.json version = 7.2.0
- [ ] README changelog updated with v7.2 section
- [ ] UPGRADING.md written (v7.1 → v7.2 steps)
- [ ] Backward compat: old `ba-start/dev-start/qa-start` redirects still work
- [ ] Backward compat: existing `.sdlc/` structures still readable
- [ ] Old `protect-spec.py` + `enforce-worktree.py` kept as `.bak`
- [ ] Regression test: full feature cycle (BA spec → DEV tasks → DEV implement → QA) on sample repo
- [ ] Regression test: parallel dev-agent spawn (2 simultaneous) completes without hang
- [ ] Regression test: single dev-agent at turn 29 gracefully exits with DONE_WITH_CONCERNS
- [ ] Hook timing benchmark: average PreToolUse < 100ms (was ~300-500ms with 2 Python forks)
- [ ] 2 team members dogfood v7.2.0-beta for 1 week minimum before stable tag

---

**END OF PLAN**
