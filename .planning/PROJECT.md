# Surypus ERP/CRM

## What This Is

Система управления предприятием нового поколения на Haskell с формальной верификацией. REST API на Scotty, PostgreSQL, двойная запись бухгалтерского учета, управление запасами, расчеты НДС, зарплата, генерация отчетов (PDF). Целевая аудитория: небольшие и средние предприятия, которым нужен надежный ERP с формальной верификацией бизнес-логики.

## Core Value

Production-ready ERP-система на Haskell, где критические бизнес-операции (бухгалтерия, склад, НДС) формально верифицируются и не ломаются в продакшене.

## Requirements

### Validated

- ✓ REST API на Scotty (порт 8080) — existing
- ✓ PostgreSQL схема (30+ таблиц) — existing  
- ✓ Базовые CRUD операции для persons, goods, bills — existing
- ✓ Тесты Hspec (32+ теста) — existing
- ✓ Docker конфигурация — existing

### Active

- [ ] API handlers с реальными DB запросами вместо заглушек
- [ ] Полный Bill posting flow (расчет сумм → движение стока → проводки)
- [ ] RBAC middleware для всех endpoints
- [ ] Event Store на основе Hasql
- [ ] WebSocket реальные уведомления
- [ ] Интеграционные тесты с реальной PostgreSQL
- [ ] Формальная верификация через LiquidHaskell

### Out of Scope

- Полноценный GraphQL API — пока достаточно REST proxy
- Мобильное приложение — фокус на web UI

## Context

### Текущее состояние

- Haskell 9.12.4, Stack build system
- Большинство handler-ов в `surypus-api/Server.hs` возвращают hardcoded данные
- Service layer частично реализован (Service/BillService.hs, Service/Accounting.hs)
- Event store объявлен но не интегрирован
- WebSocket модуль создан но не рассылает события
- Тесты требуют PostgreSQL и env-флаги для пропуска

### Технические ограничения

- PostgreSQL 14/15 нужен для интеграционных тестов
- Nix builds таймаутятся — используется system-ghc
- Нужно создать базу `surypus_test` для локального тестирования

### Приоритетные задачи

1. Подключить реальные DB запросы в API handlers
2. Завершить Bill posting flow
3. Интегрировать Event Store в сервисы

## Constraints

- **Tech stack**: Haskell 9.12.4, PostgreSQL 14+, Hasql
- **Timeline**: Phase 3 (Event Sourcing, WebSocket, GraphQL) в проgresse
- **Compatibility**: Обратная совместимость с OpenPapyrus схемой данных

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Использовать Hasql вместо Persistent | Типобезопасность, производительность | ✓ Good |
| Формальная верификация через LiquidHaskell | Критические финансовые расчеты | — Pending |
| Brownfield развитие | Есть рабочий код, нужно его довести до продакшена | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

---
*Last updated: 2026-05-12 after initialization*