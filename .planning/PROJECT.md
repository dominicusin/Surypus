# Surypus ERP/CRM

**Система управления предприятием нового поколения на Haskell с формальной верификацией**

## Current Milestone: v2.0 GUI & New Features

**Goal:** Создать QML Desktop UI, улучшить Web PWA, добавить 7 новых функциональных направлений (Dashboard/Analytics, Отчёты, CRM, Закупки/Продажи, Уведомления, Документооборот, Интеграции).

**Target features:**
- Dashboard/Analytics — графики и метрики
- Отчёты — финансовые/inventory reports
- CRM — сделки, контакты, pipeline
- Закупки/Продажи — purchase/sales orders
- Уведомления — push/email
- Документооборот — печать, PDF
- Интеграции — банки, маркетплейсы, API
- QML Desktop UI (зеркалит новые функции)
- Web PWA улучшения

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
