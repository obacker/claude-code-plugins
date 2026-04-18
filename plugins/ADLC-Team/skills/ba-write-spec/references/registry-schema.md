# Feature registry — JSON schema

Write to `.sdlc/specs/[FEAT-ID]-registry.json`. This file is the machine-readable mirror of the BDD spec. DEV and QA read it; the pretooluse-guard hook reads `spec_approved_at` to enforce spec immutability.

```json
{
  "feature_id": "[FEAT-ID]",
  "title": "[title]",
  "spec_file": "[FEAT-ID]-[slug]-spec.md",
  "spec_approved_at": null,
  "acceptance_criteria": [
    { "id": "AC-001", "description": "...", "test_function": null, "passes": null }
  ]
}
```

## Fields

- `spec_approved_at` — ISO-8601 timestamp set on approval. Once set, the spec file is immutable via the pretooluse-guard hook. To change requirements, create a new spec or request explicit re-approval.
- `acceptance_criteria[].test_function` — set by dev-agent after writing the RED test (e.g., `Test_Feature_AC1_HappyPath`).
- `acceptance_criteria[].passes` — `true` after GREEN, `false` if verification fails, `null` before implementation.
