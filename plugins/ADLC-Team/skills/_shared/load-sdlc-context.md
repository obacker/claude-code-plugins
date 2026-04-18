# Shared — Load SDLC context

Reference block used by `dev-split-tasks`, `dev-implement`, and other DEV skills to load the minimum state needed at session start. Single source of truth for "what DEV reads before planning."

## Files to read

- `.sdlc/specs/[FEAT-ID]-*-spec.md` — the approved BDD spec (source of ACs)
- `.sdlc/specs/[FEAT-ID]-registry.json` — AC tracking, approval state
- `.sdlc/domain-terms.md` — canonical terminology (no synonyms allowed)
- `.sdlc/verification.yml` — verification gates (build, lint, tests)
- `CLAUDE.md` — project stack, structure, conventions
- `.sdlc/_active/[FEAT-ID].progress.md` — if resuming work

Optional (load if the step needs it):
- `.sdlc/KNOWLEDGE.md` — harvested patterns
- `.sdlc/domain-context.md` — broader business context

## Spec approval guard

Before proceeding with task breakdown or implementation, verify the spec is approved:

```bash
python3 -c "
import sys, json
try:
    d = json.load(open('.sdlc/specs/[FEAT-ID]-registry.json'))
    if not d.get('spec_approved_at'):
        print('BLOCKED: Spec not approved yet.'); sys.exit(1)
    print(f'Spec approved at {d[\"spec_approved_at\"]}')
except Exception as e:
    print(f'BLOCKED: registry not found — {e}'); sys.exit(1)
"
```

Stop immediately if blocked.

## Verification gates

All DEV skills run `post_task` gates from `verification.yml` before declaring done. `post_slice` gates run once at slice completion. Never skip.
