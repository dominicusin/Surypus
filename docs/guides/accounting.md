# How Accounting Works

## Overview

Surypus implements double-entry bookkeeping following the accounting equation:

```
Assets = Liabilities + Equity
```

Every financial transaction must preserve this balance.

## Core Concepts

- **Debit** — left-side entry that increases assets or expenses, decreases liabilities/equity/revenue
- **Credit** — right-side entry that increases liabilities/equity/revenue, decreases assets/expenses
- **Journal Entry** — a record of one or more debit/credit pairs
- **Ledger** — the collection of all accounts and their balances

## Module Structure

```text
Core.Accounting
├── Types        -- Accounting types (JournalEntry, LedgerAccount)
├── Journal      -- Journal entry operations
├── Ledger       -- Ledger balance computation
└── Validation   -- Accounting invariant checks
```

## Journal Entry Lifecycle

1. **Create** — a new `JournalEntry` is created with debit/credit lines
2. **Validate** — `validateJournalEntry` checks that total debits = total credits
3. **Post** — posted entries update the ledger balances
4. **Close** — period-end closing entries transfer temporary account balances

## Invariants

```haskell
-- | Total debits must equal total credits for every journal entry.
--
-- >>> validateJournalEntry (JournalEntry [Debit 100, Credit 100])
-- True
validateJournalEntry :: JournalEntry -> Bool
```

## Related Modules

- `Core.Tax` — tax calculations on accounting entries
- `Core.Inventory` — inventory valuation methods
- `Finance.Accounting` — financial reporting

## See Also

- [Architecture: Event Sourcing](../architecture/EVENT_SOURCING.md)
- [Database: Accounting schema](../DATABASE.md)
- [API: Accounting endpoints](../API.md)
