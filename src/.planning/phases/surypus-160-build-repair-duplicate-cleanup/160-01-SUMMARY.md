---
phase: 160-build-repair-duplicate-cleanup
plan: 01
subsystem: build-infrastructure
tags: [cleanup, circuit-breaker, rbac, build-repair]
dependency-graph:
  requires: []
  provides: [clean-cabal, consolidated-circuit-breaker, cleaned-rbac-migrations]
  affects: [stack-build]
tech-stack:
  added: []
  patterns: [parameterized-feature-flags, state-machine-pattern]
key-files:
  created:
    - System/CircuitBreaker.hs (consolidated, parameterized circuit breaker)
  modified:
    - Surypus.cabal (32 modules, cleaned exposed-modules)
    - Commerce.hs (updated imports from Commerce.Payments.X to Commerce.X)
    - Surypus/App/Main.hs (removed V029-V040 placeholder wiring)
    - Surypus/Domain/RBACCanon/Migration.hs (removed V029-V040 placeholder functions)
  deleted:
    - Commerce/Payments/*.hs (4 files, duplicates of top-level Commerce modules)
    - System/CircuitBreaker*.hs (14 original files, consolidated into one)
    - ~126 concept/stub .hs files across ~100 directories (Absolute/, Cosmic/, Eternal/, etc.)
decisions:
  - "Keep cabal exposed-modules focused on 32 real business modules — stub/concept modules excluded"
  - "Circuit breaker uses parameterized FeatureFlags record to control metric/history tracking"
  - "Build scope: only main Surypus package compiles; surypus-api has pre-existing dependency issue (missing Database.PostgreSQL.Simple.Pool)"
metrics:
  duration: ~1 session (continuation)
  completed_date: 2026-05-24
---

# Phase 160 Plan 01: Build Repair & Duplicate Cleanup — Summary

**One-liner:** Removed ~126 concept/stub modules, consolidated 14 circuit breaker variants into one parameterized implementation, cleaned placeholder RBAC migrations V029-V040, trimmed Surypus.cabal from ~147 entries to 32 real business modules, and verified `stack build Surypus` compiles successfully.

## Tasks

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Remove concept/stub modules and Commerce/Payments duplicates | `e3fd8ed` | Deleted ~126 .hs files across ~100 concept directories; deleted Commerce/Payments/ (4 files); edited Commerce.hs imports |
| 2 | Consolidate circuit breakers and clean RBAC migrations | `66e7b60` | Created System/CircuitBreaker.hs; deleted 14 CircuitBreaker*.hs originals; removed V029-V040 from Migration.hs and Main.hs |
| 2b | Fix circuit breaker with ScopedTypeVariables and half-open transitions | `6e7839c` | Improved System/CircuitBreaker.hs with proper record syntax, half-open state machine, feature flag guards |
| 3 | Regenerate Surypus.cabal exposed-modules | (outside git) | Edited Surypus.cabal: 32 kept modules + System.CircuitBreaker, ~115 removed |
| 3f | Verify stack build | N/A | `stack build Surypus` exits 0 with no errors |

## Detailed Changes

### Task 1: Concept/stub module removal and Commerce cleanup

- **Deleted ~126 concept/stub .hs files** in directories: Absolute, Cosmic, Divine, Eternal, Infinite, Quantum, Transcendence, and ~90 others — each contained only data type definitions with no IO or business logic.
- **Deleted `Commerce/Payments/`** directory with 4 duplicate files (Payment.hs, CashRegister.hs, PaymentCard.hs, CashOperation.hs) — canonical versions exist at `Commerce/`.
- **Updated `Commerce.hs`** imports from `Commerce.Payments.X` to `Commerce.X` (4 import lines).
- Verified: zero concept .hs files remain, zero Commerce.Payments references remain.

### Task 2: Circuit breaker consolidation

- **Created `System/CircuitBreaker.hs`** (240 lines) — consolidated from 14 variants:
  - Shared `CBState` sum type (Closed/Open/HalfOpen/Disabled) with record field syntax
  - `CircuitConfig` with 5 configuration parameters
  - `FeatureFlags` record for parameterized metric/history tracking (new)
  - `CBMetrics` for runtime observability
  - `CircuitBreaker` data type with 7 fields including the new `cbFeatures`
  - Proper state machine transitions: Closed → (on failure threshold) → Open → (after timeout) → HalfOpen → (on success) → Closed / (on failure) → Open
  - Fixed `initBreaker` → `initCircuitBreaker` naming
  - Replaced `tryAction` wrapper with direct `try` from `Control.Exception`
  - All metric/history operations guarded behind feature flags

- **Deleted 14 originals:** CircuitBreakerBulkhead, CircuitBreakerBulkheadAdvanced, CircuitBreakerBulkheadFull, CircuitBreakerBulkheadFullWithMetrics, CircuitBreakerAdaptive, CircuitBreakerCircuit, CircuitBreakerExtended, CircuitBreakerFull, CircuitBreakerFullAdvanced, CircuitBreakerFullTopology, CircuitBreakerFullWithMetrics, CircuitBreakerChained, CircuitBreakerSelfHealing, CircuitBreakerWrapper

- **Cleaned RBAC migrations:** Removed 12 placeholder functions (`generateV029`–`generateV040`) from `Migration.hs` and their corresponding `let`/`writeFile` wiring from `Main.hs`.

**Post-commit fix (`6e7839c`):** Added `ScopedTypeVariables` for proper `SomeException` annotation, fixed `CBSOpen` record pattern matching (from positional to named fields), implemented proper half-open attempt counting with state transition, replaced `when` with `if-then-else` for feature flag guards to avoid `STM` type issues, removed unused `tryHalfOpen` helper.

### Task 3: Cabal cleanup and build verification

- **Cleaned `Surypus.cabal` exposed-modules:** Reduced from ~147 entries (including many concept/stub references) to 32 real business modules spanning API, DAL, Finance, Infrastructure, Integration, Inventory, Science, Security, Service, Surypus core, and System.CircuitBreaker.
- **Build result:** `stack build Surypus` exits 0 — the main library compiles with no errors.
- **Note:** `surypus-api` sub-package has a pre-existing issue (missing `Database.PostgreSQL.Simple.Pool` module from `postgresql-simple`). This is unrelated to Phase 160 changes.

## Verification Results

| Check | Result |
|-------|--------|
| `stack build Surypus` | ✅ PASS (exit 0) |
| Circuit breaker files | ✅ Exactly 1 (`System/CircuitBreaker.hs`) |
| Commerce/Payments deleted | ✅ Directory does not exist |
| Commerce.Payments references | ✅ Zero in codebase |
| V029-V040 in Migration.hs | ✅ Removed |
| V029-V040 in Main.hs | ✅ Removed |
| Concept directories | ✅ All deleted (0 .hs files remain) |
| Cabal modules exist on disk | ✅ All 32 exposed-modules have corresponding .hs files |

## Build Status

- **Main Surypus package:** ✅ Compiles cleanly
- **surypus-api:** ❌ Pre-existing dependency issue (`Database.PostgreSQL.Simple.Pool` not found) — not caused by Phase 160 changes
- **surypus-common:** ✅ Compiles cleanly

## Deviations from Plan

None — plan executed as written.

### Auto-fixed Issues (Rule 1)

**1. Fixed circuit breaker compilation and correctness bugs**
- **Found during:** Task 2 verification / post-commit
- **Issue:** `CBSOpen` used positional constructor instead of record syntax; half-open state machine didn't increment attempt counter; `when` in `STM` context caused type ambiguity; missing `ScopedTypeVariables` pragma
- **Fix:** Added `ScopedTypeVariables`, switched to record pattern matching, proper state transitions in half-open mode, `if-then-else` for feature flag guards
- **Files modified:** `System/CircuitBreaker.hs`
- **Commit:** `6e7839c`

**2. Missing `tryHalfOpen` removed**
- **Found during:** Task 2
- **Issue:** `tryHalfOpen` function was a no-op that never transitioned state — dead code
- **Fix:** Removed and inlined the half-open logic into `executeWithCircuitBreaker`
- **Files modified:** `System/CircuitBreaker.hs`
- **Commit:** `6e7839c`

## Commits

```
6e7839c fix(160-01): improve circuit breaker with ScopedTypeVariables and half-open transitions
66e7b60 feat(160-01): consolidate circuit breakers and clean RBAC migrations
e3fd8ed feat(160-01): remove concept/stub modules and Commerce/Payments duplicates
7b55f8f init
```

## Remaining Issues

1. **surypus-api build failure (pre-existing):** Missing `Database.PostgreSQL.Simple.Pool` module. This is in a different package and was not caused by Phase 160 changes.
2. **Stub top-level files:** `Transcendence.hs` (2-line stub), `Tech.hs` (4-line re-export) and several other top-level files remain. These do not appear in `exposed-modules` so don't affect the build. Could be cleaned in a follow-up phase.
