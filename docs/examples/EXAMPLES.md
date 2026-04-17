# Surypus Event Sourcing Examples

## Quick Start

### 1. Receive Stock

```sql
-- Create tenant and user first
INSERT INTO tenants (tenant_name, tenant_code) VALUES ('Test Tenant', 'test001');

-- Receive stock (creates LotCreated and StockReceived events)
SELECT cmd_inventory_receive_stock(
    gen_random_uuid(),           -- aggregate_id
    (SELECT tenant_id FROM tenants LIMIT 1),
    NULL,                        -- user_id
    gen_random_uuid(),           -- goods_id
    gen_random_uuid(),           -- location_id
    100.0,                       -- qty
    10.0,                        -- cost
    15.0,                        -- price
    'LOT-001',                   -- lot_number
    NULL,                        -- expiry_date
    NULL                         -- document_ref
);
```

### 2. Issue Stock (FIFO)

```sql
-- Issue stock (creates LotConsumed and StockIssued events)
SELECT * FROM cmd_inventory_issue_stock(
    aggregate_id,              -- same aggregate
    tenant_id,
    NULL,                      -- user_id
    goods_id,                  -- same goods
    location_id,               -- same location
    50.0,                      -- qty_needed
    NULL,                      -- document_ref
    NULL                       -- expected_version
);
-- Returns: lot_id, qty_used, cost, amount for each lot consumed
```

### 3. Check Stock Balance

```sql
-- Query projection (read model)
SELECT * FROM stock_get_balance(goods_id, location_id);

-- Or query specific goods across all locations
SELECT * FROM projection_stock_balance
WHERE goods_id = '...';
```

### 4. Create and Post Bill

```sql
-- Create bill
SELECT cmd_bill_create(
    gen_random_uuid(),
    tenant_id,
    NULL,
    'INV-001',
    CURRENT_DATE,
    person_id,
    location_id,
    op_kind_id,
    'Notes here',
    NULL
);

-- Add line
SELECT cmd_bill_add_line(
    bill_aggregate_id,
    tenant_id,
    NULL,
    NULL,           -- line_id (auto-generated)
    goods_id,
    10.0,           -- quantity
    100.0,          -- price
    0.0,            -- discount
    20.0,           -- vat_rate
    NULL            -- expected_version
);

-- Post bill (triggers stock movements and accounting entries)
SELECT cmd_bill_post(
    bill_aggregate_id,
    tenant_id,
    NULL,
    NULL            -- expected_version
);
```

### 5. Saga Execution

```sql
-- Start sales order saga
SELECT saga_create(
    'sales_order',
    gen_random_uuid(),
    tenant_id,
    input_data := '{
        "inventory_aggregate": "...",
        "bill_aggregate": "...",
        "goods_id": "...",
        "location_id": "...",
        "person_id": "...",
        "qty": 10.0,
        "price": 100.0,
        "cost": 50.0,
        "vat_rate": 20.0,
        "bill_code": "INV-001"
    }'::jsonb
);

-- Execute steps one by one
SELECT saga_execute_step(saga_id, tenant_id, NULL);

-- Check status
SELECT * FROM saga_get_status(saga_id);
```

## Haskell Examples

### Event Store Operations

```haskell
{-# LANGUAGE OverloadedStrings #-}

import Surypus.Core.EventStore

main :: IO ()
main = do
    -- Create event store connection
    let store = mkEventStore "postgresql://..."
    
    -- Append event
    result <- appendEvent store
        aggregateId
        "Inventory"
        "StockReceived"
        (object ["qty" .= (100 :: Double), "cost" .= (10 :: Double)])
        tenantId
        Nothing  -- expected version
    
    case result of
        Left err -> putStrLn $ "Error: " ++ err
        Right (eventId, seqNum) -> do
            putStrLn $ "Event appended: " ++ show eventId
            putStrLn $ "Sequence: " ++ show seqNum
    
    -- Get events
    events <- getEvents store aggregateId
    mapM_ print events
```

### Inventory Operations

```haskell
import Surypus.Domain.Inventory

main :: IO ()
main = do
    -- Create initial state
    let stock = emptyStock
    
    -- Define commands
    let receiveCmd = ReceiveStock
            { rcGoodsId = goodsId
            , rcLocationId = locationId
            , rcQty = 100.0
            , rcCost = 10.0
            }
    
    -- Execute command
    case executeCommand stock receiveCmd of
        Left violation -> print violation
        Right (newStock, events) -> do
            putStrLn $ "New stock qty: " ++ show (unQuantity $ currentQty newStock)
            putStrLn $ "Events generated: " ++ show (length events)
```

### Saga Orchestration

```haskell
import Surypus.Core.Saga

main :: IO ()
main = do
    -- Define saga
    let salesOrderSaga = Saga
            { sagaType = "sales_order"
            , sagaSteps =
                [ Step "reserve_stock" reserveStockHandler
                , Step "create_bill" createBillHandler
                , Step "post_bill" postBillHandler
                , Step "issue_stock" issueStockHandler
                ]
            }
    
    -- Execute saga
    result <- runSaga salesOrderSaga sagaInput
    
    case result of
        SagaCompleted -> putStrLn "Saga completed successfully"
        SagaFailed err -> putStrLn $ "Saga failed: " ++ err
        SagaCompensated -> putStrLn "Saga compensated after failure"
```

## REST API Examples

### cURL Examples

```bash
# Receive stock
curl -X POST http://localhost:3000/api/v1/inventory/receive \
  -H "Content-Type: application/json" \
  -H "X-API-Key: your-key" \
  -d '{
    "aggregateId": "...",
    "goodsId": "...",
    "locationId": "...",
    "qty": 100,
    "cost": {"currency": "USD", "amountCents": 10000}
  }'

# Issue stock
curl -X POST http://localhost:3000/api/v1/inventory/issue \
  -H "Content-Type: application/json" \
  -d '{
    "aggregateId": "...",
    "goodsId": "...",
    "locationId": "...",
    "qty": 50,
    "method": "FIFO"
  }'

# Get stock balance
curl "http://localhost:3000/api/v1/inventory/balance?goodsId=...&locationId=..."

# Start saga
curl -X POST http://localhost:3000/api/v1/sagas \
  -H "Content-Type: application/json" \
  -d '{
    "sagaType": "sales_order",
    "correlationId": "...",
    "inputData": {...}
  }'
```

## Event Streaming

### Subscribe to Events

```haskell
import Surypus.Client.EventStream

main :: IO ()
main = do
    -- Connect to event stream
    withEventStream "localhost:9092" $ \stream -> do
        -- Subscribe to inventory events
        subscribe stream ["surypus.events.inventory.*"]
        
        -- Process events
        forever $ do
            event <- nextEvent stream
            case eventType event of
                "StockReceived" -> handleStockReceived event
                "StockIssued"   -> handleStockIssued event
                _               -> return ()
```

## Monitoring Queries

```sql
-- System health
SELECT * FROM metrics_get_system_health();

-- Event processing stats
SELECT * FROM metrics_event_stats_hourly
WHERE hour >= NOW() - INTERVAL '1 hour';

-- Projection lag
SELECT * FROM metrics_projection_lag_current;

-- Saga execution stats
SELECT * FROM metrics_saga_stats_daily
WHERE day >= CURRENT_DATE - INTERVAL '7 days';

-- Command execution stats
SELECT * FROM metrics_command_stats_daily;
```

## Common Patterns

### 1. Replay Projections

```sql
-- Truncate and rebuild projection
TRUNCATE projection_fifo_lots;
TRUNCATE projection_stock_balance;

-- Replay events (would be done by projection service)
SELECT rebuild_all_projections();
```

### 2. Temporal Query

```sql
-- State at specific point in time
SELECT aggregate_id, event_type, event_data
FROM event_store
WHERE aggregate_id = '...'
  AND created_at <= '2024-01-01 00:00:00'
ORDER BY sequence_number;
```

### 3. Event Audit Trail

```sql
-- Full history for aggregate
SELECT 
    es.created_at,
    es.event_type,
    es.event_data,
    es.user_id,
    es.correlation_id
FROM event_store es
WHERE es.aggregate_id = '...'
ORDER BY es.sequence_number;
```

## Testing Examples

### Unit Test with InMemory Store

```haskell
import Test.Hspec
import Surypus.Test.InMemory

spec :: Spec
spec = do
    describe "Inventory Aggregate" $ do
        it "should maintain quantity invariant" $ do
            let stock = emptyStock
                receive = ReceiveStock {...}
            
            case executeCommand stock receive of
                Right (newStock, _) -> do
                    unQuantity (currentQty newStock) `shouldBe` 100.0
                Left err -> expectationFailure $ show err
```

### Property Test

```haskell
import Test.QuickCheck

prop_quantityConserved :: Stock -> Command -> Property
prop_quantityConserved stock cmd =
    case executeCommand stock cmd of
        Left _ -> property True
        Right (newStock, _) -> let oldTotal = sumLots (stockLots stock)
                                   newTotal = sumLots (stockLots newStock)
                               in case cmd of
                                   ReceiveStock{..} -> newTotal == oldTotal + rcQty
                                   IssueStock{..}   -> oldTotal == newTotal + isQty
                                   _                -> True
```
