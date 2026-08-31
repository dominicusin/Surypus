# How Inventory Lifecycle Works

## Overview

Surypus tracks inventory through a complete lifecycle from procurement to consumption/sale.

## Core Concepts

- **Goods** — product catalog items
- **Stock** — physical inventory holdings at warehouses
- **Lot** — a batch of goods with specific properties (expiry, manufacture date)
- **Movement** — any change in stock quantity (receipt, issue, transfer)

## Lifecycle Stages

```text
Procurement          Receipt             Storage             Sale/Consumption
    │                    │                    │                    │
    ▼                    ▼                    ▼                    ▼
 Purchase          Goods Received       Stock on Hand       Goods Shipped
 Order             → Lot Created        → Lot Picked        → Stock Reduced
```

## Key Operations

1. **Receive Goods** — `receiveGoods` creates a new `Goods` record and initial `Stock`
2. **Issue Stock** — `issueStock` reduces stock, creates a `Lot` if needed
3. **Transfer** — `transferStock` moves stock between warehouses
4. **Adjust** — `adjustStock` corrects inventory counts (shrinkage, damage)

## Invariants

```haskell
-- | Stock rest must equal initial + receipts - issues.
--
-- >>> checkStockRest initial receipts issues
-- True
checkStockRest :: Int -> Int -> Int -> Bool
```

## Valuation Methods

Surypus supports multiple inventory valuation methods:

- **FIFO** — First In, First Out
- **LIFO** — Last In, First Out
- **Weighted Average** — Average cost per unit

## Related Modules

- `Core.Inventory` — inventory types and operations
- `Core.Stock` — stock management
- `Core.Goods` — goods catalog
- `Core.Warehouse` — warehouse management

## See Also

- [Architecture: Domain Model](../architecture/EVENT_SOURCING.md)
- [Database: Inventory schema](../DATABASE.md)
