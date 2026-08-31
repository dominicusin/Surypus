# How Event Store Works

## Overview

Surypus uses an Event Store pattern for auditability and event sourcing capabilities.

## Core Concepts

- **Event** — an immutable fact that happened in the system
- **Event Stream** — a sequence of events for an aggregate
- **Snapshot** — a periodic checkpoint of aggregate state
- **Event Bus** — publishes events to subscribers

## Event Store Module Structure

```text
Surypus.EventStore
├── Types        -- Event types (Event, EventStream, Snapshot)
├── Append       -- Event append operations
├── Query        -- Event query and reading
├── Snapshot     -- Snapshot management
└── PubSub       -- Event publishing and subscriptions
```

## Event Lifecycle

```text
Domain Event
    │
    ▼
  Append ──► Event Store (immutable log)
    │
    ▼
  Publish ──► Event Bus ──► Subscribers
    │
    ▼
  Snapshot (periodic) ──► Aggregate state cache
```

## Event Types

| Event | Description |
|-------|-------------|
| `BillCreated` | A new bill was created |
| `BillApproved` | A bill was approved |
| `PaymentReceived` | Payment was recorded |
| `InventoryAdjusted` | Inventory was adjusted |
| `UserRoleChanged` | RBAC role was modified |

## Snapshots

Snapshots are taken after N events to avoid replaying the entire stream:

```haskell
-- | Create or retrieve a snapshot for an aggregate.
--
-- >>> getSnapshot "bill-123"
-- Just (Snapshot "bill-123" 42 events)
getSnapshot :: AggregateId -> IO (Maybe Snapshot)
```

## Related Modules

- `EventBus` — event publishing
- `Core.Accounting` — accounting events
- `Core.Inventory` — inventory events

## See Also

- [Architecture: Event Sourcing](../architecture/EVENT_SOURCING.md)
- [Persistence Guide](../guides/persistence.md)
