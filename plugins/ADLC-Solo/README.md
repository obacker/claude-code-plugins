# ADLC v12 — Agent-Driven Lifecycle

Structured feature development for Claude Code: BDD specs, TDD implementation, automated review, and verification gates.

## What It Does

ADLC enforces a disciplined development lifecycle:

1. **Specification** — BDD acceptance criteria written by a specialized spec-writer agent (Opus)
2. **Planning** — Features decomposed into parallel-friendly implementation tasks
3. **Implementation** — Each task runs in an isolated worktree with strict TDD (iron law: no code without a failing test)
4. **Review** — Two-stage: spec compliance first (qa-tester), then code quality (pr-review-toolkit)
5. **Verification** — Automated gates from verification.yml, feature-registry cross-checks

After spec approval, acceptance criteria become **immutable** — enforced by a PreToolUse hook that blocks edits.

## Install

```bash
# Install ADLC Solo
/plugin install adlc-solo@obacker-claude-code-plugins

# Install required companion plugins
/plugin install pr-review-toolkit@claude-plugins-official
/plugin install commit-commands@claude-plugins-official

# Install recommended companions
/plugin install claude-md-management@claude-plugins-official
/plugin install context7@claude-plugins-official
/plugin install github@claude-plugins-official

# Install LSP for your stack
/plugin install typescript-lsp@claude-plugins-official  # or pyright-lsp, gopls-lsp, etc.

# Initialize in your project
adlc-init
```

## Commands

| Command | Description |
|---------|-------------|
| `/adlc:build-feature [description]` | Full lifecycle: spec → plan → implement → review → QA → verify |
| `/adlc:bugfix [description]` | Lightweight fix with root-cause analysis |
| `/adlc:explore` | Map existing codebase |
| `/adlc:plan-milestone [description]` | Decompose epic into milestones |
| `/adlc:plan-slice [milestone-id]` | Break milestone into dev tasks |
| `/adlc:review-slice [id slice-N]` | Post-slice validation |
| `/adlc:start-session` | Resume from where you left off |

## Architecture

```
3 agents:   spec-writer (Opus) → dev-agent (Sonnet, worktree) → qa-tester (Sonnet, main tree)
7 skills:   build-feature, plan-milestone, plan-slice, review-slice, start-session, bugfix, explore
4 hooks:    protect-spec (PreToolUse), enforce-worktree (PreToolUse), on-agent-stop (SubagentStop), save-context (PreCompact)
7 companions: pr-review-toolkit, commit-commands, claude-md-management, context7, github, security-guidance, LSP
```

## Key Enforcement

| What | How | Level |
|------|-----|-------|
| Spec immutability | `protect-spec.py` PreToolUse hook | Platform (hook blocks the action) |
| Worktree-only code edits | `enforce-worktree.py` PreToolUse hook | Platform (hook blocks the action) |
| Worktree isolation | `isolation: worktree` in frontmatter | Platform (automatic) |
| Tool restrictions | `tools:` in agent frontmatter | Platform (enforced) |
| Model routing | `model:` in agent frontmatter | Platform (enforced) |
| Turn limits | `maxTurns:` in agent frontmatter | Platform (enforced) |
| TDD iron law | Agent instructions + anti-rationalization list | Instruction (strict) |
| Two-stage review | build-feature skill orchestration | Instruction (ordered phases) |
| Verification gates | verification.yml commands | Command (exit code) |

## Companion Plugin Roles

- **pr-review-toolkit**: 6 specialized code review agents (replaces ADLC's former review-agent)
- **commit-commands**: Tool-restricted git operations (agents can't construct arbitrary git commands)
- **claude-md-management**: CLAUDE.md quality auditing and improvement
- **context7**: Live API/library documentation during development
- **github**: GitHub issues, PRs, Projects integration
- **security-guidance**: Lightweight security reminders on file edits
- **LSP**: Code intelligence (go-to-definition, diagnostics, type checking)

## Requirements

- Claude Code with plugin support
- Git initialized project
- Python 3.x (for protect-spec.py hook)
- Bash (for shell hooks)

## License

MIT — oBacker (obacker.com)
