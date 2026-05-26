# Surypus Refactoring Summary - DDD / Event Sourcing / PostgreSQL / RBAC / OPA

## Executive Summary

Полный рефакторинг Surypus с традиционных SQL процедур на современную архитектуру:

- ✅ **Domain-Driven Design (DDD)**
- ✅ **Event Sourcing** с append-only event store
- ✅ **CQRS** (Command Query Responsibility Segregation)
- ✅ **Multi-tenant** с tenant isolation
- ✅ **RBAC** (Role-Based Access Control)
- ✅ **OPA** (Open Policy Agent) для политик
- ✅ **Saga Pattern** для распределенных транзакций
- ✅ **Kafka/Redpanda** для event streaming
- ✅ **Formal Verification** на Haskell

## Directory Structure

```
Surypus/
├── sql/
│   ├── event/              # Event Store (append-only)
│   │   ├── V001__event_store.sql
│   │   └── V002__kafka_streams.sql
│   ├── aggregate/          # Domain Aggregates
│   │   ├── V001__inventory_aggregate.sql
│   │   └── V002__bill_aggregate.sql
│   ├── projection/         # Read Models
│   │   └── V001__fifo_projection.sql
│   ├── command/            # Command Handlers
│   ├── core/               # Core Services (RBAC)
│   │   └── V001__rbac_schema.sql
│   ├── policy/             # Saga Orchestrator
│   │   └── V001__saga_orchestrator.sql
│   └── service/            # Metrics & Monitoring
│       └── V001__metrics_collection.sql
├── src/surypus-es/         # Haskell Formal Model
│   ├── Core/
│   │   └── EventStore.hs   # Event store formalization
│   └── Domain/
│       └── Inventory.hs    # Domain invariants
├── api/
│   ├── rest/
│   │   └── openapi.yaml    # OpenAPI specification
│   └── grpc/
│       └── surypus.proto   # gRPC services
├── opa/
│   └── policies/
│       ├── rbac.rego       # RBAC policies
│       └── inventory.rego  # Domain policies
├── docker/
│   └── docker-compose.yml  # Full stack deployment
├── tests/
│   └── integration/
│       └── test_event_sourcing.py
└── docs/
    └── architecture/
        └── EVENT_SOURCING.md
```

## Key Components

### 1. Event Store (Append-Only)

```sql
-- Ядро системы - неизменяемый лог событий
CREATE TABLE event_store (
    event_id            BIGSERIAL PRIMARY KEY,
    aggregate_id        UUID NOT NULL,
    aggregate_type      VARCHAR(64) NOT NULL,
    event_type          VARCHAR(128) NOT NULL,
    event_version       INT NOT NULL,
    event_data          JSONB NOT NULL,
    tenant_id           UUID NOT NULL,  -- Multi-tenant
    sequence_number     BIGINT NOT NULL, -- Global ordering
    created_at          TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Append event
SELECT event_append(
    aggregate_id,
    'Inventory',
    'StockReceived',
    '{"qty": 100, "cost": 10.0}'::jsonb,
    tenant_id,
    expected_version := 5  -- Optimistic concurrency
);
```

### 2. Inventory Aggregate

```sql
-- Commands
SELECT cmd_inventory_receive_stock(...);  -- Создает партии
SELECT cmd_inventory_issue_stock(...);    -- FIFO списание
SELECT cmd_inventory_adjust_stock(...);   -- Корректировка

-- Rebuild aggregate from events
SELECT inventory_rebuild(aggregate_id);
```

### 3. FIFO Projection (Read Model)

```sql
-- Проекция для быстрых запросов
CREATE TABLE projection_fifo_lots (
    lot_id              UUID PRIMARY KEY,
    goods_id            UUID NOT NULL,
    location_id         UUID NOT NULL,
    qty_remaining       NUMERIC NOT NULL,
    lot_cost            NUMERIC NOT NULL,
    received_at         TIMESTAMP WITH TIME ZONE
);

-- Query FIFO lots
SELECT * FROM projection_lots_fifo(goods_id, location_id, qty_needed);
```

### 4. Saga Orchestrator

```sql
-- Distributed transaction example
SELECT saga_create(
    'sales_order',           -- saga type
    correlation_id,
    tenant_id,
    '{...}'::jsonb           -- input data
);

-- Execute step
SELECT saga_execute_step(saga_id, tenant_id);

-- Compensation on failure
SELECT saga_compensate(saga_id, tenant_id);
```

### 5. RBAC + OPA

```sql
-- Permission check
SELECT has_permission(user_id, 'inventory', 'write', tenant_id);

-- Generate OPA input
SELECT generate_opa_input(user_id, resource, action, tenant_id);
```

```rego
# OPA Policy (rbac.rego)
package surypus.rbac

default allow := false

allow if {
    is_superuser
}

allow if {
    has_permission(input.resource, input.action)
    belongs_to_tenant
}

deny if {
    input.user.is_active == false
}
```

### 6. Event Streaming (Kafka/Redpanda)

```sql
-- Outbox pattern for reliable publishing
CREATE TABLE event_outbox (
    outbox_id           BIGSERIAL PRIMARY KEY,
    event_id            BIGINT NOT NULL UNIQUE,
    event_type          VARCHAR(128) NOT NULL,
    topic               VARCHAR(256) NOT NULL,
    published           BOOLEAN DEFAULT FALSE
);

-- Trigger auto-populates outbox
CREATE TRIGGER trg_event_outbox
    AFTER INSERT ON event_store
    FOR EACH ROW EXECUTE FUNCTION trg_event_to_outbox();
```

### 7. Formal Model (Haskell)

```haskell
-- Invariant checking
class AggregateState s where
    emptyState :: s
    applyEvent :: s -> Event -> Either InvariantViolation s
    checkInvariants :: s -> Maybe InvariantViolation

-- Properties
data InvariantViolation
    = NegativeQuantity Double
    | InsufficientStock { needed :: Double, available :: Double }
    | InvalidStatus Text Text

-- FIFO properties
prop_fifoOrder :: [Lot] -> Quantity -> Bool
prop_quantityConserved :: Stock -> Command -> Bool
prop_cannotOverIssue :: Stock -> Quantity -> Bool
```

## Migration Guide

### From Old Procedures to Event Sourcing

| Old Procedure | New Approach |
|--------------|--------------|
| `fifo_select_lots()` | `projection_lots_fifo()` + `cmd_inventory_issue_stock()` |
| `calc_stock_balance()` | `stock_get_balance()` projection query |
| `create_bill()` | `cmd_bill_create()` + events |
| `post_bill()` | `cmd_bill_post()` with saga |
| Direct SQL updates | Event appending only |

### Running Migrations

```bash
# Apply Event Sourcing migrations
psql -d surypus -f sql/migrations/V100__event_sourcing_init.sql

# Run tests
psql -d surypus -f sql/test/V001__test_event_store.sql
psql -d surypus -f sql/test/V002__test_inventory_aggregate.sql

# Python integration tests
pytest tests/integration/test_event_sourcing.py -v
```

## Docker Deployment

```bash
# Full stack
docker-compose -f docker/docker-compose.yml up -d

# Services:
# - PostgreSQL:5432     - Event Store
# - OPA:8181           - Policy Engine
# - Redpanda:9092      - Event Streaming
# - Surypus API:3000   - REST/gRPC API
# - Grafana:3001       - Dashboards
# - Prometheus:9090    - Metrics
```

## API Endpoints

### REST (OpenAPI)

```yaml
POST /api/v1/inventory/receive    # Receive stock
POST /api/v1/inventory/issue      # Issue stock (FIFO)
GET  /api/v1/inventory/balance    # Query stock balance
POST /api/v1/bills               # Create bill
POST /api/v1/bills/{id}/post     # Post bill
POST /api/v1/sagas               # Start saga
```

### gRPC

```protobuf
service CommandService {
  rpc ReceiveStock(ReceiveStockRequest) returns (CommandResponse);
  rpc IssueStock(IssueStockRequest) returns (IssueStockResponse);
}

service QueryService {
  rpc GetStockBalance(GetStockBalanceRequest) returns (StockBalanceResponse);
}

service SagaService {
  rpc StartSaga(StartSagaRequest) returns (StartSagaResponse);
}
```

## Key Benefits

### 1. Audit Trail
Все изменения сохранены в event store - полная история.

### 2. Temporal Queries
```sql
-- Состояние на любую дату
SELECT * FROM event_store
WHERE aggregate_id = '...'
  AND created_at <= '2024-01-01'
ORDER BY sequence_number;
```

### 3. Replay Capability
```sql
-- Перестроить проекции с нуля
TRUNCATE projection_fifo_lots;
-- Replay events
SELECT rebuild_projection('inventory_fifo_projection');
```

### 4. Scalability
- **Write**: PostgreSQL (vertical scale)
- **Read**: Projections (horizontal scale via read replicas)
- **Events**: Kafka (horizontal scale via partitions)

### 5. Resilience
- **Sagas** обеспечивают консистентность
- **Compensation** откатывает при ошибках
- **OPA** централизованная авторизация

## Metrics & Monitoring

### Dashboard (Grafana)

- Events Processed (1h)
- Max Projection Lag
- Avg Event Processing Time
- Failed Sagas

### Key Metrics

```sql
-- Projection lag
SELECT * FROM metrics_projection_lag_current;

-- System health
SELECT * FROM metrics_get_system_health();

-- Event processing stats
SELECT * FROM metrics_event_stats_hourly;
```

## Testing

### Unit Tests
```bash
# Event store tests
psql -d surypus -f sql/test/V001__test_event_store.sql

# Inventory aggregate tests
psql -d surypus -f sql/test/V002__test_inventory_aggregate.sql
```

### Integration Tests
```bash
# Python tests
pytest tests/integration/test_event_sourcing.py -v

# Tests cover:
# - Event appending
# - FIFO ordering
# - Optimistic concurrency
# - Saga execution
# - Compensation
```

## Next Steps

1. **Migrate remaining aggregates** (Person, Salary, Accounting)
2. **Implement event handlers** in Haskell
3. **Add GraphQL API** layer
4. **Setup CI/CD** pipelines
5. **Performance tuning** (partitioning, indexing)
6. **Disaster recovery** procedures

## References

- [Event Sourcing](https://martinfowler.com/eaaDev/EventSourcing.html)
- [CQRS](https://martinfowler.com/bliki/CQRS.html)
- [Saga Pattern](https://microservices.io/patterns/data/saga.html)
- [OPA](https://www.openpolicyagent.org/)
- [Redpanda](https://redpanda.com/)

---

**Status**: ✅ Core implementation complete  
**Test Coverage**: Event Store, Inventory Aggregate, FIFO Projection, Saga  
**Documentation**: OpenAPI, Architecture, Examples
