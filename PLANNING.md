# Project Planning: Surypus ERP/CRM

## Цели проекта (Strategic Goals)

Production-ready ERP-система на Haskell, где критические бизнес-операции (бухгалтерия, склад, НДС) формально верифицируются через LiquidHaskell.

## Текущий статус (Current State)

Проект находится на этапе **Phase 3 (Event Sourcing & Infra) - COMPLETE**. 
Phase 160 (Integration API Implementation) - COMPLETE.

### Выполнено (Validated)
- ✓ REST API на Scotty (OpenAPI 3.0)
- ✓ Слой доступа к данным (DAL) на Hasql/Rel8
- ✓ JWT Аутентификация и Refresh Tokens
- ✓ Role-Based Access Control (RBAC)
- ✓ Бухгалтерский учет (Двойная запись)
- ✓ Управление запасами и расчет НДС
- ✓ Кастомная система SQL миграций
- ✓ PDF-отчеты (PDF-Slave/JasperReports)
- ✓ Интеграция Event Store (Hasql)
- ✓ WebSocket уведомления в реальном времени
- ✓ Формальная верификация (Smart constructors)
- ✓ Redis Queue для фоновых задач
- ✓ Integration API (Bank statement upload, Health check, Status endpoints)

### В процессе (Active)
- None - all planned infrastructure phases complete

## Дорожная карта (Roadmap)

### Phase 1 — API Production Readiness (Completed)
- Реальные DB запросы в APIHandlers
- JWT Middleware & RBAC
- Интеграционные тесты

### Phase 2 — Bill Posting & Accounting (Completed)
- Атомарный процесс проведения документов (Stock + Accounting)
- Property-based testing (QuickCheck)
- OpenAPI/Swagger генерация

### Phase 3 — Event Sourcing & Infra (Current)
- **Plan 3.1**: Hasql Event Store — Сохранение событий в БД
- **Plan 3.2**: Event-Driven Accounting — Перевод проводок на события
- **Plan 3.3**: WebSocket Broadcast — Уведомления об изменениях
- **Plan 3.4**: Redis Task Queue — Фоновая обработка отчетов

## Требования (Requirements)

### Функциональные
- **API-01**: Полное покрытие REST эндпоинтов реальными данными.
- **BILL-01**: Атомарная транзакция: документ -> сток -> проводки.
- **EVT-01**: Хранение и replay событий для восстановления состояния.
- **WS-01**: Оповещение UI об изменениях без перезагрузки.

### Качественные
- **TEST-01**: 100% прохождение интеграционных тестов в CI.
- **VERIF-01**: Отсутствие ошибок переполнения и отрицательных сумм (LiquidHaskell).
- **SEC-01**: RBAC проверка на уровне middleware для каждого запроса.

---
*Последнее обновление: 2026-05-14*
