---
name: explore
description: Map an existing codebase — architecture, patterns, dependencies, test coverage, domain concepts. Produces an exploration report.
---

# ADLC Explore

Systematically map an existing codebase to build understanding before starting development.

## When to Use

- Starting work on an unfamiliar codebase
- Before planning a new milestone in an area you haven't touched
- When domain-context.md is empty or outdated

## Process

### Step 1: Project Overview

1. Read CLAUDE.md, README.md, package.json / go.mod / pyproject.toml / Cargo.toml
2. Identify: language, framework, build system, test framework, deployment target
3. Read .env.example or similar for external dependencies (databases, APIs, services)

### Step 2: Architecture Map

1. List top-level directories and their purpose
2. Identify architectural pattern: MVC, clean architecture, hexagonal, monolith, microservices
3. Find entry points: main files, route definitions, handler registrations
4. Map dependency flow: which modules depend on which?
5. Identify shared code: utils, helpers, common types

### Step 3: Domain Analysis

1. Read existing domain-context.md and domain-terms.md
2. Grep for domain-specific types, interfaces, and constants
3. Identify bounded contexts: which parts of the code own which domain concepts?
4. Note terminology: what do they call things? (exact terms matter for ADLC specs)

### Step 4: Test Coverage

1. Find test files: `**/*test*`, `**/*spec*`
2. Count: test files vs production files
3. Run test suite if verification.yml exists
4. Identify: well-tested areas vs gaps
5. Note test patterns: unit, integration, e2e, mocking strategy

### Step 5: Code Health

1. Check for: TODO/FIXME/HACK comments
2. Identify: dead code, unused imports, deprecated patterns
3. Note: recent activity (`git log --oneline -20`)
4. Check: CI/CD config if present

## Output

Write exploration report to `.sdlc/exploration-report.md`:

```markdown
# Exploration Report: [Project Name]
Generated: [date]

## Stack
[language] / [framework] / [database] / [infra]

## Architecture
[pattern] — [1-2 sentence description]
[directory map with purpose annotations]

## Domain Concepts
[key entities and their relationships]
[terminology that must be used in specs]

## Test Coverage
[summary: X test files, Y production files]
[well-tested areas]
[gaps]

## Code Health
[TODOs: X, FIXMEs: Y]
[recent activity summary]
[notable patterns or concerns]

## Recommended First Steps
[what to tackle first based on findings]
```

## Step 6: Update Project Knowledge

**Exploration is only valuable if it persists. Update knowledge files from findings.**

1. **domain-context.md** — If empty or outdated:
   - Write/update architecture overview (pattern, modules, data flow)
   - Write/update external dependencies (databases, APIs, services)
   - Write/update deployment context (target, CI/CD, environments)
   - If domain-context.md already exists and is accurate: skip

2. **domain-terms.md** — If empty or missing terms found in codebase:
   - Add domain-specific types, entities, and status values discovered
   - Add business concepts with definitions from code context
   - If domain-terms.md already exists and is complete: skip

3. **Present changes to user** before committing:
   - Show what was added/updated in each file
   - Ask for corrections (you may have inferred wrong meanings)

## Rules

- This is READ-ONLY exploration for source code. Never modify production code or test files.
- domain-context.md and domain-terms.md are knowledge files — these ARE expected outputs of exploration
- Don't run destructive commands (npm run clean, database resets, etc.)
- If you find secrets in the codebase: flag them but don't include in report
