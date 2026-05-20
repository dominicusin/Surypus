---
inclusion: always
description: Testing standards and TDD approach
---
# Testing Standards

## Approach
TDD: Red → Green → Refactor

## Test Types
- Unit: Individual functions (`test/Domain/`)
- Integration: Component interactions (`test/Integration/`)
- API: Endpoint tests (`test/API/`)
- DAL: Database layer (`test/DAL/`)
- SQL: DB-level invariant tests (`sql/test/` — 116 files)

## Frameworks
- **HSpec** — primary test framework
- **QuickCheck** — property-based testing for domain invariants
- Run: `stack test`

## Coverage
- All domain modules: unit + property-based tests required
- All API endpoints: integration test required
- Financial calculations: LiquidHaskell verification + QuickCheck properties
- CI: `.github/workflows/ci.yml`
