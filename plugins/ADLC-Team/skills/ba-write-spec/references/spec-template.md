# BDD spec template

Write to `.sdlc/specs/[FEAT-ID]-[slug]-spec.md`.

```markdown
# [FEAT-ID]: [Feature Title]

## Overview
[2-3 sentences describing the feature and its value]

## Actors
- [Actor 1]: [role description]

## Acceptance Criteria

### AC-001: [Short description]
**Given** [precondition with concrete values]
**When** [action with specific input]
**Then** [expected outcome with measurable result]

### AC-002: ...

## Edge Cases
- [Edge case 1]: [expected behavior]

## Out of Scope
- [Explicitly excluded items]

## Risk Flags
- [ ] Database migration required
- [ ] Authentication/authorization changes
- [ ] Financial transaction logic
- [ ] PII/sensitive data handling
- [ ] Breaking API changes
- [ ] Infrastructure/deployment changes

## Dependencies
- [Upstream/downstream dependencies]
```

## Writing rules (apply while drafting)

- Given/When/Then on every AC.
- Concrete values only — no "some value", "valid input", "appropriate response".
- WHAT not HOW — no implementation details.
- One interpretation per AC. Rewrite if ambiguous.
- Domain terms must match `.sdlc/domain-terms.md` exactly.
