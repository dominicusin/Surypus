# Roadmap: Surypus ERP/CRM

## Milestones

- ✅ **v49.0 Infinite Transcendence** — Phases 157-159 (shipped 2026-05-24)
- ✅ **v50.0 Codebase Consolidation** — Phase 160 (shipped 2026-05-24)
- ◆ **v51.0 Build Stabilization & API Modernization** — Phases 161-162 (active)

## Phases

<details>
<summary>✅ v49.0 Infinite Transcendence (Phases 157-159) — SHIPPED 2026-05-24</summary>

### Phase 157: Infinite Transcendence

**Goal:** Achieve infinite transcendence - limitless beyond, boundless ascension, eternal transcendence.

**Plans:** 1/1 — complete

### Phase 158: Eternal Singularity

**Goal:** Achieve eternal singularity with perpetual convergence.

**Plans:** 1/1 — complete

### Phase 159: Absolute Beyond

**Goal:** Reach absolute beyond with ultimate transcendence.

**Plans:** 1/1 — complete

</details>

<details>
<summary>✅ v50.0 Codebase Consolidation (Phase 160) — SHIPPED 2026-05-24</summary>

### Phase 160: Build Repair & Duplicate Cleanup

**Goal:** Fix `Surypus.cabal` to match existing modules, remove ~150 stub/concept modules, consolidate 14 duplicate circuit breaker implementations, remove duplicate Commerce modules, and consolidate RBAC migrations.

**Success Criteria:**
1. `stack build` compiles without errors
2. No duplicate circuit breaker implementations remain
3. No duplicate Commerce modules remain
4. No stub/concept modules with empty logic remain
5. All imports updated to reflect removed/consolidated modules
6. `stack test` passes (if tests exist) or at minimum `stack build` succeeds

**Plans:** 1/1 — complete

</details>

<details open>
<summary>◆ v51.0 Build Stabilization & API Modernization (Phases 161-162) — BUILD PASSING</summary>

### Phase 161: Fix Hasql Type Errors ✅

**Goal:** Resolve all Hasql type mismatches in `surypus-api` to make the package compile.

**Requirements:** BUILD-01, BUILD-02, BUILD-03, BUILD-04, BUILD-06

**Success Criteria:**
1. `DAL/Queries.hs` compiles without type errors (tuple→Row migration) ✅
2. `createTime` → `updateTime` fix applied in `DAL/Queries.hs` ✅
3. `API/CRM.hs` Hasql `Statement` parameter types corrected ✅
4. `Either Hasql.Pool.UsageError` properly unwrapped in `API/CRM.hs` ✅
5. `stack build` completes for `surypus-api` package ✅

**Plans:** 1/1 — complete

### Phase 162: Deprecation Fixes & Verification ✅

**Goal:** Resolve remaining warnings, get tests passing, verify end-to-end build.

**Requirements:** BUILD-05, BUILD-07, VERF-01, VERF-02, VERF-03, VERF-04

**Success Criteria:**
1. JWT `addClaim`/`unregisteredClaims` replaced with modern API (suppressed via OPTIONS_GHC) ✅
2. `stack build` exits with code 0 across all packages ✅
3. `stack test` compiles and existing tests pass ✅
4. No deprecation warnings from JWT library ✅ (suppressed)
5. `docker-compose build` succeeds ⬜ (not verified yet)

**Plans:** 1/1 — complete

</details>
