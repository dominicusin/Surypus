# Surypus Event Sourcing Architecture

## Overview

Surypus реализована на основе **Event Sourcing** и **CQRS** паттернов для обеспечения:

- Полной аудируемости всех изменений
- Восстановления состояния системы на любую дату
- Масштабируемости через разделение read/write моделей
- Надежности через Saga-оркестрацию

## Архитектура

```
┌─────────────────────────────────────────────────────────────────┐
│                         API Layer                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │
│  │  REST API    │  │   gRPC API   │  │   GraphQL (future)   │   │
│  └──────────────┘  └──────────────┘  └──────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Command Layer                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │
│  │  Commands    │  │   OPA AuthZ  │  │   Saga Orchestrator  │   │
│  └──────────────┘  └──────────────┘  └──────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Event Store                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │
│  │  PostgreSQL  │  │   Outbox     │  │   Kafka/Redpanda   │   │
│  │  (events)    │  │   Pattern    │  │   (streaming)      │   │
│  └──────────────┘  └──────────────┘  └──────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Projection Layer                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │
│  │   FIFO Lots  │  │   Stock Bal  │  │   Bill Projections   │   │
│  └──────────────┘  └──────────────┘  └──────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Query Layer                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │
│  │  Read Models │  │   Cache      │  │   Search Index       │   │
│  └──────────────┘  └──────────────┘  └──────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

## Core Principles

### 1. Event Store (Append-Only)

```sql
-- Events никогда не удаляются и не обновляются
CREATE TABLE event_store (
    event_id            BIGSERIAL PRIMARY KEY,
    aggregate_id        UUID NOT NULL,
    event_type          VARCHAR(128) NOT NULL,
    event_data          JSONB NOT NULL,
    sequence_number     BIGINT NOT NULL,  -- Global ordering
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

### 2. Aggregate Pattern

```haskell
-- Aggregate = функция над событиями
class AggregateState s where
    emptyState :: s
    applyEvent :: s -> Event -> Either InvariantViolation s
```

**Пример: Inventory Aggregate**

```
Events: [LotCreated, StockReceived, LotConsumed, StockIssued]
  │
  ▼
State: { current_qty, reserved_qty, available_qty, lots: [...] }
  │
  ▼
Invariants: current_qty >= 0, available_qty >= 0, etc.
```

### 3. CQRS (Command Query Responsibility Segregation)

| Aspect | Commands | Queries |
|--------|----------|---------|
| Write | Event Store | - |
| Read | - | Projections |
| Scale | Vertically | Horizontally |
| Consistency | Strong | Eventual |

### 4. Saga Pattern

Для распределенных транзакций:

```
Sales Order Saga:
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ Reserve Stock│───▶│ Create Bill  │───▶│  Post Bill   │
└──────────────┘    └──────────────┘    └──────────────┘
       │                   │                   │
       ▼                   ▼                   ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ Release Res. │◀───│ Cancel Bill  │◀───│ Reverse Stock│
└──────────────┘    └──────────────┘    └──────────────┘
        
        Compensation (при ошибке выполняется в обратном порядке)
```

## Event Types

### Inventory Domain

| Event | Description |
|-------|-------------|
| `StockReceived` | Поступление товара на склад |
| `StockIssued` | Списание товара по FIFO |
| `StockReserved` | Резервирование товара |
| `StockReleased` | Снятие резерва |
| `StockAdjusted` | Корректировка остатка |
| `LotCreated` | Создание партии |
| `LotConsumed` | Потребление партии |

### Bill Domain

| Event | Description |
|-------|-------------|
| `BillCreated` | Создание документа |
| `BillLineAdded` | Добавление строки |
| `BillPosted` | Проведение документа |
| `BillCancelled` | Отмена документа |

## Projections (Read Models)

### FIFO Lots Projection

```sql
CREATE TABLE projection_fifo_lots (
    lot_id              UUID PRIMARY KEY,
    goods_id            UUID NOT NULL,
    location_id         UUID NOT NULL,
    qty_remaining       NUMERIC NOT NULL,
    lot_cost            NUMERIC NOT NULL,
    received_at         TIMESTAMP WITH TIME ZONE
);

-- Query: Get FIFO lots for goods issuance
SELECT * FROM projection_lots_fifo(goods_id, location_id, qty_needed);
```

### Stock Balance Projection

```sql
CREATE TABLE projection_stock_balance (
    goods_id            UUID NOT NULL,
    location_id         UUID NOT NULL,
    current_qty         NUMERIC NOT NULL,
    reserved_qty        NUMERIC NOT NULL,
    available_qty       NUMERIC NOT NULL,
    avg_cost            NUMERIC GENERATED ALWAYS AS (CASE WHEN current_qty > 0 THEN total_cost / current_qty ELSE 0 END) STORED,
    PRIMARY KEY (goods_id, location_id)
);
```

## Согласованность и инварианты

### Оптимистичная блокировка

```sql
-- При appending event проверяется версия
SELECT event_append(
    aggregate_id,
    'Inventory',
    'StockIssued',
    '{...}',
    tenant_id,
    expected_version := 5  -- Проверка версии
);
-- Возвращает ошибку если версия не совпадает
```

### Invariant Checking

```haskell
-- Примеры инвариантов
data InvariantViolation
    = NegativeQuantity Double
    | InsufficientStock { needed :: Double, available :: Double }
    | InvalidStatus Text Text

-- Проверка перед выполнением команды
validateCommand :: Command -> Either InvariantViolation ()
```

## Event Streaming

### Outbox Pattern

```sql
-- Триггер автоматически создает запись в outbox
CREATE TRIGGER trg_event_outbox
    AFTER INSERT ON event_store
    FOR EACH ROW
    EXECUTE FUNCTION trg_event_to_outbox();

-- Event Publisher читает outbox и публикует в Kafka
```

### Kafka Topics

```
surypus.events.inventory.StockReceived
surypus.events.inventory.StockIssued
surypus.events.bill.BillPosted
surypus.projections.updates
surypus.commands.execute
```

## Monitoring

### Key Metrics

| Metric | Description | Alert Threshold |
|--------|-------------|-----------------|
| `event_processing_time` | Время обработки события | > 100ms |
| `projection_lag` | Отставание проекций | > 1000 events |
| `saga_completion_rate` | Успешность саг | < 95% |
| `command_execution_time` | Время выполнения команд | > 500ms |

## Deployment

### Docker Compose

```bash
# Запуск всего стека
docker-compose -f docker/docker-compose.yml up -d

# Сервисы:
# - PostgreSQL (Event Store)
# - Redpanda (Event Streaming)
# - OPA (Authorization)
# - Surypus API
# - Event Publisher
# - Projection Builder
```

## Formal Verification

Haskell модель обеспечивает:

```haskell
-- Свойства FIFO
prop_fifoOrder :: [Lot] -> Quantity -> Bool
prop_quantityConserved :: Stock -> Command -> Bool
prop_cannotOverIssue :: Stock -> Quantity -> Bool
```

## References

- [Event Sourcing Pattern](https://martinfowler.com/eaaDev/EventSourcing.html)
- [CQRS Pattern](https://martinfowler.com/bliki/CQRS.html)
- [Saga Pattern](https://microservices.io/patterns/data/saga.html)
- [Outbox Pattern](https://microservices.io/patterns/data/transactional-outbox.html)
