# Phase 160: Build Repair & Duplicate Cleanup - Context

**Gathered:** 2026-05-24
**Status:** Ready for planning
**Mode:** Auto-generated (discuss skipped via workflow.skip_discuss)

<domain>
## Phase Boundary

Fix `Surypus.cabal` to match existing modules, remove ~150 stub/concept modules, consolidate 14 duplicate circuit breaker implementations, remove duplicate Commerce modules, and consolidate RBAC migrations.

**Requirements:**
- Fix `Surypus.cabal` exposed-modules to match `.hs` files on disk
- Remove `src/Cosmic*/`, `src/Eternal*/`, `src/Divine*/`, `src/Absolute*/`, etc. stub modules (~150 files)
- Consolidate 14 `System/CircuitBreaker*.hs` into single parameterized `System/CircuitBreaker.hs`
- Remove duplicate `Commerce/Payments/*.hs` (keep canonical `Commerce/*.hs`)
- Consolidate 40 RBAC migrations (remove V029-V040 placeholders)
- Verify `stack build` succeeds

**Success Criteria:**
1. `stack build` compiles without errors
2. No duplicate circuit breaker implementations remain
3. No duplicate Commerce modules remain
4. No stub/concept modules with empty logic remain
5. All imports updated to reflect removed/consolidated modules
6. `stack test` passes (if tests exist) or at minimum `stack build` succeeds
</domain>

<decisions>
## Implementation Decisions

### the agent's Discretion
All implementation choices are at the agent's discretion — discuss phase was skipped per user setting. Use ROADMAP phase goal, success criteria, and codebase conventions to guide decisions.

### Key Approach
1. First fix `Surypus.cabal` to list only real modules (those with actual logic)
2. Remove stub/concept directories entirely (Cosmic/, Eternal/, Divine/, etc.)
3. Consolidate circuit breakers: keep parameterized `System/CircuitBreaker.hs`, remove 13 duplicates
4. Remove duplicate Commerce/Payments/ modules, update imports across codebase
5. Remove placeholder RBAC migrations V029-V040
6. Verify with `stack build`
</decisions>

<code_context>
## Existing Code Insights

See `.planning/codebase/` for full codebase analysis:
- `CONCERNS.md` — Details all tech debt items targeted in this phase
- `STACK.md` — Stack LTS 22.21, GHC 9.6.5
- `ARCHITECTURE.md` — Module organization and boundaries
- `CONVENTIONS.md` — Code style and patterns for Haskell modules
</code_context>

<specifics>
## Specific Ideas

1. **Cabal fix:** Run `find src -name "*.hs" | sort` to get actual modules, diff against `Surypus.cabal` exposed-modules, add missing and remove absent ones
2. **Stub removal:** Delete directories: Cosmic*, Eternal*, Divine*, Absolute*, Infinite*, Quantum*, etc. — any module that only defines types with no IO or business logic
3. **Circuit breaker:** Create `System/CircuitBreaker.hs` with configurable strategies via sum type, re-export old names from wrappers for backward compat
4. **Commerce cleanup:** Delete `Commerce/Payments/` directory, update all imports from `Commerce.Payments.X` to `Commerce.X`
5. **Migration cleanup:** Remove V029-V040 placeholder files from `sql/migrations/`, simplify `Main.hs`
</specifics>

<deferred>
## Deferred Ideas

None — discuss phase skipped.
</deferred>
