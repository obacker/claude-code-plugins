# Changelog

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
