# Roadmap: Surypus ERP/CRM

## Phase 1 — API Production Readiness

**Goal:** API возвращает реальные данные, аутентификация работает, тесты проходят

- **Plan 1.1:** Подключить реальные DB запросы в API handlers
- **Plan 1.2:** JWT authentication middleware для всех endpoints  
- **Plan 1.3:** RBAC проверка прав (requirePermission)
- **Plan 1.4:** Интеграционные тесты с PostgreSQL

## Phase 2 — Bill Posting & Event Store

**Goal:** Полный цикл создания документа с проводками и событиями

- **Plan 2.1:** Bill posting flow (CalcBillLineAmount → StockMovements → AccTurn)
- **Plan 2.2:** Hasql-based Event Store в DAL/EventStore.hs
- **Plan 2.3:** Интеграция Event Store в сервисы
- **Plan 2.4:** QuickCheck property tests для инвариантов

## Phase 3 — WebSocket & Events

**Goal:** Реальное время и асинхронная обработка

- **Plan 3.1:** WebSocket рассылает события о документах
- **Plan 3.2:** Redis Queue для background задач
- **Plan 3.3:** GraphQL proxy для REST API

---

**Total Phases:** 3
**Total Plans:** 11