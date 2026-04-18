---
name: dev-cost-report
description: "Generate a weekly ADLC cost and usage audit from session logs. Trigger: 'cost report', 'weekly cost', 'token audit', 'adlc usage report'. Run by lead DEV weekly; surfaces per-agent token burn, sonnet/haiku ratio, hang events, and sessions over budget."
---

<context>
You produce a week-in-review cost dashboard so the team can see whether the plugin is actually cheaper than working without it. Read-only — you analyze logs, you do not change code.
</context>

<instructions>

## Step 1 — Collect raw data

Read from the last 7 days:
- `.sdlc/agent-log.txt` — completion records, WARN entries, harvest events
- `.sdlc/_active/*.progress.md` — per-feature task status
- `.sdlc/reviews/*-report.md` — QA findings
- `gh` — recent PRs, issue transitions

If Claude Code Insights is available, fetch the session token breakdown. Otherwise, estimate from `agent-log.txt` entries.

## Step 2 — Compute metrics

Per the week:
- **Agent runs** — count by role (ba / dev / qa) and by model (sonnet / haiku / opus-advisor).
- **Sonnet-vs-haiku ratio for DEV** — target is 60/40 (see v7.2 plan). Flag if sonnet > 80%.
- **Hang / HUNG events** — grep `agent-log.txt` for `HUNG` and worktree force-removals.
- **Turn-limit stalls** — count `DONE_WITH_CONCERNS` and `PASS_WITH_CONCERNS` entries.
- **Per-feature token estimate** — sum across spawns for each `[FEAT-ID]`.
- **Sessions over budget** — flag any feature burning > 2× the median.

## Step 3 — Write report

Output to `.sdlc/reports/cost-report-[YYYY-WW].md`:

```markdown
# ADLC cost report — week [YYYY-WW]

## Headline
- Agent runs: [N] (ba=[N], dev=[N], qa=[N])
- Model mix (DEV): sonnet [N%] / haiku [N%] / advisor-opus [N%]
- Hang events: [N]
- Turn-limit stalls: [N]
- PRs opened: [N], merged: [N]

## Per-feature
| Feature | Runs | Est. tokens | Hangs | Notes |
|---|---|---|---|---|
| FEAT-001 | 4 | ~40K | 0 | baseline |

## Flags
- [ ] Feature X burned 3× the median — investigate task sizing
- [ ] Sonnet share > 80% — review Haiku routing
- [ ] Hang rate > 1/week — review timeout policy

## Recommendations
1. [Concrete follow-up]
2. [Concrete follow-up]
```

## Step 4 — Share

Post a short summary to `#adlc` Slack / team channel with the headline numbers and top 1-2 flags. Link to the full report file.

</instructions>

<documents>
- `.sdlc/agent-log.txt` — raw event log
- `.sdlc/_active/*.progress.md` — per-feature progress
- `.sdlc/reviews/` — QA reports
- `.sdlc/reports/` — prior cost reports for trend comparison
</documents>
