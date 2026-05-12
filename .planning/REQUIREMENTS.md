# Requirements: Surypus ERP/CRM

**Defined:** 2026-05-12
**Core Value:** Production-ready ERP-система на Haskell, где критические бизнес-операции формально верифицируются и не ломаются в продакшене

## v1 Requirements

### API Integration

- [ ] **API-01**: API handlers возвращают реальные DB данные вместо заглушек
- [ ] **API-02**: JWT authentication middleware защищает все endpoints
- [ ] **API-03**: RBAC проверка прав на каждый запрос
- [ ] **API-04**: Пагинация и фильтры для списков (persons, goods, bills)

### Bill Processing

- [ ] **BILL-01**: POST /bills создает документ с расчетом сумм
- [ ] **BILL-02**: POST /bills/{id}/post создает проводки и движение стока
- [ ] **BILL-03**: НДС расчитывается корректно для разных ставок
- [ ] **BILL-04**: Атомарная транзакция: расчет → сток → проводки

### Event Store

- [ ] **EVT-01**: События сохраняются в event_store таблицу
- [ ] **EVT-02**: Surypus.Event эмитит события при изменениях
- [ ] **EVT-03**: Accounting и Inventory сервисы используют Event Store
- [ ] **EVT-04**: Replay восстанавливает состояние из событий

### Testing

- [ ] **TEST-01**: Интеграционные тесты работают с реальной PostgreSQL
- [ ] **TEST-02**: Все тесты проходят без SURYPUS_SKIP_RBAC_TESTS
- [ ] **TEST-03**: QuickCheck property tests для бизнес-инвариантов
- [ ] **TEST-04**: Test fixtures для создания тестовых данных

### WebSocket

- [ ] **WS-01**: WebSocket рассылает события о новых документах
- [ ] **WS-02**: Room-based подписки по типу сущности
- [ ] **WS-03**: Интеграция с EventBus для broadcast

## v2 Requirements

### Formal Verification

- [ ] **LH-01**: LiquidHaskell типы для VAT (NonNeg верификация)
- [ ] **LH-02**: LiquidHaskell типы для бухгалтерских проводок
- [ ] **LH-03**: LiquidHaskell типы для остатков на складе

### Advanced Features

- [ ] **HR-01**: Модуль Payroll с расчетом зарплаты
- [ ] **PROD-01**: Модуль Production (tech cards, work orders, MRP)
- [ ] **MULTI-01**: Много-валютность с конвертацией

## Out of Scope

| Feature | Reason |
|---------|--------|
| Полноценный GraphQL API | REST proxy достаточен для v1 |
| Мобильное приложение | Web UI + PWA покрывает потребности |
| OAuth внешних провайдеров | Email/password для v1 достаточно |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| API-01 | Phase 1 | Pending |
| API-02 | Phase 1 | Pending |
| API-03 | Phase 1 | Pending |
| API-04 | Phase 1 | Pending |
| BILL-01 | Phase 2 | Pending |
| BILL-02 | Phase 2 | Pending |
| BILL-03 | Phase 2 | Pending |
| BILL-04 | Phase 2 | Pending |
| EVT-01 | Phase 3 | Pending |
| EVT-02 | Phase 3 | Pending |
| EVT-03 | Phase 3 | Pending |
| EVT-04 | Phase 3 | Pending |
| TEST-01 | Phase 1 | Pending |
| TEST-02 | Phase 1 | Pending |
| TEST-03 | Phase 2 | Pending |
| TEST-04 | Phase 2 | Pending |
| WS-01 | Phase 3 | Pending |
| WS-02 | Phase 3 | Pending |
| WS-03 | Phase 3 | Pending |

**Coverage:**
- v1 requirements: 16 total
- Mapped to phases: 16
- Unmapped: 0 ✓

---
*Requirements defined: 2026-05-12*
*Last updated: 2026-05-12 after initial definition*