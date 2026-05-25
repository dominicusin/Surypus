# Surypus ERP/CRM

**Система управления предприятием нового поколения на Haskell с формальной верификацией**

## Current Milestone: v51.0 Build Stabilization & API Modernization

**Goal:** Fix remaining build errors in `surypus-api`, resolve deprecation warnings, and establish a reliable build pipeline.

**Target features:**
- Fix Hasql type mismatches in `DAL/Queries.hs` and `API/CRM.hs`
- Resolve JWT `addClaim`/`unregisteredClaims` deprecation warnings
- Ensure `stack build` succeeds across all packages
- Fix `stack test` — get existing test suite passing
- Update Dockerfile to work with fixed build
- Verify CI pipeline passes

## Completed Milestones

- ✅ **v50.0 Codebase Consolidation** — Build repair, duplicate cleanup, module consolidation (shipped 2026-05-25)
- ✅ **v49.0 Infinite Transcendence** — Phases 157-159 (shipped 2026-05-24)
- ✅ **v2.0 GUI & New Features** — Dashboard, CRM, QML UI, Notifications, Reports, POs, Docs, Integrations (shipped 2026-05-18)
- ✅ **v1.0** — Foundation: RBAC, JWT, Hasql/PostgreSQL, LiquidHaskell (shipped 2026-05-18)

## Vision

Построить современную ERP/CRM систему на Haskell с:
- Event Sourcing для аудита и надежности
- LiquidHaskell для верификации бизнес-логики
- REST API на Scotty
- QML Desktop UI + Web PWA

## Non-Negotiables

1. Все финансовые расчеты верифицируются LiquidHaskell
2. Event Sourcing для критических изменений
3. RBAC с JWT аутентификацией
4. PostgreSQL 16+ с Hasql/Rel8 ORM

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition:**
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone:**
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state
