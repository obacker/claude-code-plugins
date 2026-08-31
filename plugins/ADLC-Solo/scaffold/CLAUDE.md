# {{PROJECT_NAME}}

## Stack
{{STACK}}

## Commands
- Build: `{{BUILD_CMD}}`
- Lint: `{{LINT_CMD}}`
- Test: `{{TEST_CMD}}`
- Dev server: `{{DEV_CMD}}`

## Project files
- `domain-context.md`: architecture, constraints, integration quirks
- `domain-terms.md`: exact domain vocabulary. Use these terms; never invent synonyms.
- `verification.yml`: the commands that must pass

## Working agreement
- Write the minimum code that solves the stated problem. No unrequested
  abstractions, config knobs, or features.
- Touch only what must change. No drive-by refactors or reformats.
- Surface trade-offs when there are several approaches; do not silently pick one.
- Nothing is done until the verification commands pass.

## Sensitive changes
Anything touching money, invoicing, tax, auth, permissions, or database
migrations gets a failing test first, committed before the implementation.
Everything else does not need that.

## Conventions
{{Add project-specific conventions here. Examples:}}
- Go: every exported struct field carries a json tag.
- Frontend: do not remove a CSS class without checking usage across all files.
- Tailwind v4: use `@import` syntax, not `@tailwind` directives.
- Docker: build for linux/amd64.

## Deployment
{{Add project-specific deployment procedures here.}}

## Workflow commands
- `/adlc:feature [description]`: build a feature
- `/adlc:bugfix [description]`: fix a defect
- `/adlc:ship`: pre-commit verification and review gate
