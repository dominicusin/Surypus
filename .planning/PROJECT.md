# Surypus ERP/CRM

**Система управления предприятием нового поколения на Haskell с формальной верификацией**

## Current Milestone: v50.0 Codebase Consolidation

**Goal:** Fix the build, eliminate technical debt, and establish a maintainable foundation.

**Target features:**
- Fix `Surypus.cabal` to match actual modules on disk
- Remove ~150 stub/concept modules with no real logic
- Consolidate 14 duplicate circuit breaker implementations into one
- Remove duplicate Commerce modules
- Consolidate 40 RBAC migrations

## Completed Milestones

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

**After each milestone:**
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state
