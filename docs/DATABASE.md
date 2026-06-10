# Хранилище данных

> Раздел описывает схему базы данных, миграции, механизмы обеспечения консистентности (ACID) и паттерны работы с PostgreSQL.

---

## 1. Общая схема (Entity-Relationship)

```
┌─────────────┐     ┌──────────────┐     ┌──────────────┐
│   Person    │     │    Goods     │     │   Location   │
│─────────────│     │──────────────│     │──────────────│
│ id          │────>│ id           │     │ id           │
│ code        │     │ code         │     │ code         │
│ name        │     │ name         │     │ name         │
│ inn         │     │ barcode      │<────│ locationType │
│ kpp         │     │ categoryId   │     └──────┬───────┘
│ personType  │     │ unitId       │            │
│ status      │     │ price        │            │
└──────┬──────┘     └──────┬───────┘            │
       │                   │                    │
       │     ┌─────────────┴─────────────┐      │
       │     │                           │      │
       │     ▼                           ▼      │
       │  ┌──────────────┐     ┌──────────────┐ │
       │  │  BillLine    │     │    Stock     │ │
       │  │──────────────│     │──────────────│ │
       │  │ id           │     │ goodsId      │ │
       │  │ billId ──────│──┐  │ locationId ──│─│──┐
       │  │ goodsId ─────│──│──│ qtty         │ │  │
       │  │ qtty         │  │  │ resrvQtty    │ │  │
       │  │ price        │  │  └──────────────┘ │  │
       │  │ amount       │  │                   │  │
       │  └──────────────┘  │                   │  │
       │                    │                   │  │
       │  ┌──────────────┐  │   ┌──────────────┐│  │
       │  │    Bill      │  │   │     Lot      ││  │
       │  │──────────────│  │   │──────────────││  │
       │  │ id           │  │   │ id           ││  │
       │  │ code         │  │   │ goodsId ─────││──│──
       │  │ billType     │  │   │ locationId ──││──│──
       └──│ personId     │  │   │ billId ──────│──┘  │
          │ locationId   │  │   │ dt           │     │
          │ total        │  │   │ expDt        │     │
          │ docStatus    │  │   │ rest         │     │
          │ docDate      │  │   │ cost         │     │
          └──────────────┘  │   │ price        │     │
                            │   │ serial       │     │
                            │   │ flags        │     │
                            │   └──────────────┘     │
                            │                        │
  ┌──────────────┐          │                        │
  │  AccEntry    │          │                        │
  │──────────────│          │                        │
  │ id           │          │                        │
  │ docId ───────│──────────┘                        │
  │ debit        │                                   │
  │ credit       │                                   │
  │ amount       │                                   │
  │ date         │                                   │
  │ descr        │                                   │
  └──────────────┘                                   │
                                                     │
  ┌──────────────┐     ┌──────────────┐              │
  │   Tenant     │     │    User      │              │
  │──────────────│     │──────────────│              │
  │ id           │────>│ id           │              │
  │ name         │     │ username     │              │
  │ slug         │     │ passwordHash │              │
  └──────────────┘     │ tenantId ────│──────────────┘
                       │ email        │
                       │ role         │
                       └──────────────┘
```

---

## 2. Сущности Persistent (43 шт.)

### 2.1. Основные регистры

| Сущность | Таблица | Описание | Ключевые поля |
|----------|---------|----------|---------------|
| `PersonEntity` | `person` | Контрагенты | code, name, inn, kpp, personType, status |
| `GoodsEntity` | `goods` | Номенклатура | code, name, barcode, categoryId, unitId, price |
| `LocationEntity` | `location` | Склады | code, name, locationType |
| `UnitEntity` | `unit` | Единицы измерения | code, name |
| `CurrencyEntity` | `currency` | Валюты | code, name, rate |
| `TaxEntity` | `tax` | Налоговые ставки | code, name, rate, flags |

### 2.2. Документы

| Сущность | Таблица | Описание | Ключевые поля |
|----------|---------|----------|---------------|
| `BillEntity` | `bill` | Счета/накладные | billType, docStatus, docDate, personId, locationId, total |
| `BillLineEntity` | `bill_line` | Позиции счёта | billId, goodsId, qtty, price, amount |
| `OrderHeadEntity` | `order_head` | Заказы | status, docDate |
| `OrderLineEntity` | `order_line` | Позиции заказа | orderId, goodsId, qtty |
| `PaymentEntity` | `payment` | Платежи | billId, amount, paymentDate, status |

### 2.3. Склад

| Сущность | Таблица | Описание | Ключевые поля |
|----------|---------|----------|---------------|
| `StockEntity` | `stock` | Текущие остатки | goodsId, locationId, qtty, resrvQtty |
| `LotEntity` | `lot` | Партии (FIFO) | goodsId, locationId, billId, dt, expDt, rest, cost, price |

### 2.4. Бухгалтерия

| Сущность | Таблица | Описание | Ключевые поля |
|----------|---------|----------|---------------|
| `AccPlanEntity` | `acc_plan` | План счетов | code, name, type, parentId |
| `AccTurnEntity` | `acc_turn` | Обороты | accId, period, debit, credit |
| `AccEntry` (raw) | `acc_entry` | Проводки | docId, debit, credit, amount, date |

### 2.5. HR

| Сущность | Таблица | Описание | Ключевые поля |
|----------|---------|----------|---------------|
| `EmployeeEntity` | `employee` | Сотрудники | personId, code, name, position |
| `SalaryEntity` | `salary` | Зарплата | employeeId, period, amount, status |

### 2.6. CRM

| Сущность | Таблица | Описание |
|----------|---------|----------|
| `ContactEntity` | `contact` | Контакты |
| `CompanyEntity` | `company` | Компании |
| `DealEntity` | `deal` | Сделки |
| `PipelineEntity` | `pipeline` | Воронки продаж |

### 2.7. Системные

| Сущность | Таблица | Описание | Ключевые поля |
|----------|---------|----------|---------------|
| `UserEntity` | `user` | Пользователи | username, passwordHash, tenantId, role |
| `TenantEntity` | `tenant` | Организации | name, slug |
| `SessionEntity` | `session` | Сессии | userId, token, expiresAt |
| `JobEntity` | `jobs` | Фоновые задачи | jobType, status, payload |

### 2.8. Event Store

| Сущность | Таблица | Описание |
|----------|---------|----------|
| `EventStore` (raw) | `event_store` | append-only лог событий |

---

## 3. Индексы и оптимизация

```sql
── Основные индексы
CREATE INDEX idx_bill_docdate ON bill (doc_date);
CREATE INDEX idx_bill_person ON bill (person_id);
CREATE INDEX idx_bill_docstatus ON bill (doc_status);
CREATE INDEX idx_billline_bill ON bill_line (bill_id);
CREATE INDEX idx_stock_goods_location ON stock (goods_id, location_id);
CREATE INDEX idx_lot_goods ON lot (goods_id);
CREATE INDEX idx_lot_fifo ON lot (goods_id, location_id, dt);
CREATE INDEX idx_entry_doc ON acc_entry (doc_id);
CREATE INDEX idx_entry_date ON acc_entry (date);
CREATE INDEX idx_job_status ON jobs (status);

── Полнотекстовый поиск
CREATE INDEX idx_goods_name_fts ON goods USING gin (to_tsvector('russian', name));
```

---

## 4. Миграции

### Порядок применения

Миграции в `sql/migrations/`, нумерация V000–V999:

| Диапазон | Назначение |
|----------|------------|
| V000–V020 | Начальная схема (person, goods, bills, stock, users) |
| V100–V200 | Event Sourcing, проекции, партиционирование, CQRS, CRM |
| V200–V300 | Enterprise: API gateway, data warehouse, ML |
| V300–V400 | RBAC каноническая модель (V307–V434) |
| V450–V500 | RBAC concurrency benchmarks |
| V500+ | Классификаторы, production, интеграции |

### Применение миграций

```bash
── Применить все pending миграции
psql -h localhost -U surypus -d surypus -f sql/migrations/V<номер>.sql

── Или через Makefile
make migrate
```

### Принципы

- Миграции только вперёд (no rollback)
- Обратная совместимость: новые колонки с DEFAULT или NULL
- Data migrations отдельно от schema migrations
- Каждая миграция в отдельном файле

---

## 5. ACID-консистентность

### Транзакции для ключевых операций

```sql
── Проведение счёта (Bill.Post) — одна транзакция
BEGIN;
  ── 1. Проверка остатков
  SELECT qtty FROM stock WHERE goods_id = ? AND location_id = ? FOR UPDATE;

  ── 2. Списание по FIFO
  UPDATE lots SET rest = rest - ? WHERE id = ? AND rest >= ?;

  ── 3. Обновление остатка
  UPDATE stock SET qtty = qtty - ? WHERE goods_id = ? AND location_id = ?;

  ── 4. Проводка
  INSERT INTO acc_entry (doc_id, debit, credit, amount) VALUES (?, ?, ?, ?);

  ── 5. Событие в EventStore
  INSERT INTO event_store (aggregate_id, event_type, payload) VALUES (?, ?, ?);

  ── 6. Обновление статуса
  UPDATE bill SET doc_status = 'POSTED' WHERE id = ?;
COMMIT;
```

### Блокировки

| Уровень | Метод | Где используется |
|---------|-------|-----------------|
| Оптимистичная | `retry` в STM | Кэши в памяти |
| Пессимистичная | `SELECT ... FOR UPDATE` | Остатки, партии (PostgreSQL) |
| Advisory lock | `pg_advisory_xact_lock()` | Job worker-ы |

### Констрейнты

```sql
── NOT NULL + CHECK constraints
ALTER TABLE stock ADD CONSTRAINT stock_qtty_nonneg CHECK (qtty >= 0);
ALTER TABLE lot ADD CONSTRAINT lot_rest_nonneg CHECK (rest >= 0);
ALTER TABLE acc_entry ADD CONSTRAINT acc_entry_amount_nonneg CHECK (amount >= 0);
ALTER TABLE goods ADD CONSTRAINT goods_price_nonneg CHECK (price >= 0);

── UNIQUE
ALTER TABLE person ADD CONSTRAINT person_inn_unique UNIQUE (inn);
ALTER TABLE goods ADD CONSTRAINT goods_code_unique UNIQUE (code, tenant_id);
ALTER TABLE tenant ADD CONSTRAINT tenant_slug_unique UNIQUE (slug);
ALTER TABLE "user" ADD CONSTRAINT user_username_unique UNIQUE (username);

── Foreign Keys (через Persistent)
└── Все ссылки имеют FOREIGN KEY с CASCADE на DELETE
```

### Обеспечение консистентности в Haskell

```haskell
── Транзакция на уровне приложения
postBill :: BillID -> DB (Either ServiceError ())
postBill bid = do
  pool <- asks envPool
  result <- liftIO $ withTransaction pool $ do
    -- 1. lock
    lots <- selectForUpdate bid
    -- 2. validate
    unless (all (\l -> lotRest l >= 0) lots) $
      rollback "negative lot rest"
    -- 3. update
    updateLots lots
    updateStock lots
    insertEntries bid lots
    updateStatus bid POSTED
    appendEvent bid GoodsShipped
  return $ case result of
    Left err  -> Left $ DBError err
    Right ()  -> Right ()

── STM для in-memory операций
atomically $ modifyTVar' stockTVar $ M.adjust (+delta) key
```

---

## 6. Event Store (PostgreSQL)

### Схема

```sql
CREATE TABLE event_store (
  id          BIGSERIAL PRIMARY KEY,
  aggregate_id   TEXT NOT NULL,
  event_type  TEXT NOT NULL,
  payload     JSONB NOT NULL,
  version     INT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_event_aggregate ON event_store (aggregate_id, version);
CREATE INDEX idx_event_type ON event_store (event_type);
CREATE INDEX idx_event_time ON event_store (created_at);
```

### Принципы

- Append-only: события только добавляются, никогда не изменяются
- Version — optimistic lock для конкурентного доступа
- Payload — JSONB с полными данными события
- Проекции обновляются асинхронно

---

## 7. Redis (кэш и очереди)

| Назначение | Тип | Ключ |
|-----------|-----|------|
| Кэш остатков | String | `stock:{goodsId}:{locationId}` |
| Кэш сессий | String | `session:{token}` |
| Очередь задач | List | `jobs:pending` |
| Pub/Sub уведомления | Channel | `notifications:*` |

---

## 8. Связанные документы

- `sql/docs/ARCHITECTURE.md` — Архитектура SQL-слоя
- `sql/docs/CHANGELOG.md` — История изменений БД
- `docs/architecture/EVENT_SOURCING.md` — Event Sourcing
- `DAL/Schema.hs` — Persistent-определения (source of truth для схемы)
- `sql/migrations/` — 370+ файлов миграций
