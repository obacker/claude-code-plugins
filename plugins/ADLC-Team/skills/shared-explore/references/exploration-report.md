# Exploration report template

Write to `.sdlc/exploration-report.md`.

```markdown
# Codebase Exploration Report

## Stack
- **Language:** [X]
- **Framework:** [X]
- **Database:** [X]
- **Test framework:** [X]
- **Build/lint:** [X]

## Architecture
[Pattern, entry points, key directories]

## Domain Concepts
[Key entities, relationships, business rules]
[Seed terms for domain-terms.md]

## Test Coverage
- Test files: [N]
- Production files: [N]
- Well-tested areas: [list]
- Gaps: [list]

## Code Health
- TODOs: [N]
- Recent activity: [pattern]
- Key concerns: [list]

## Recommended First Steps
1. [Most impactful action]
2. [Second action]
3. [Third action]
```

## Stack signatures

| File | Stack |
|---|---|
| `package.json`, `tsconfig.json` | Node.js / TypeScript |
| `go.mod` | Go |
| `pyproject.toml`, `requirements.txt` | Python |
| `Cargo.toml` | Rust |
| `pom.xml`, `build.gradle` | Java / Kotlin |
| `Dockerfile`, `docker-compose.yml` | Containerization |

## Architecture map commands

```bash
find . -type d -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/vendor/*' -not -path '*/__pycache__/*' | head -50
```

## Domain scan

```bash
grep -r "type\|interface\|class\|model\|schema" --include="*.ts" --include="*.go" --include="*.py" -l
```

## Test coverage scan

```bash
find . -name "*test*" -o -name "*spec*" | grep -v node_modules | grep -v vendor
```

## Scaffold files to generate (only if `.sdlc/` is missing)

- `.sdlc/domain-context.md` — from exploration findings
- `.sdlc/domain-terms.md` — seed from domain analysis
- `.sdlc/verification.yml` — from detected stack
