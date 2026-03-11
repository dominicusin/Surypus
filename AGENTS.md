# AGENTS.md - Surypus Development Guide

## Project Overview

This repository contains:
- **Surypus/** - Haskell reimplementation with formal verification (target for new development)

Primary development focus is on the Haskell codebase (Surypus).

---

## Build Commands

### Surypus (Haskell)

```bash
# Build the project
cd Surypus && stack build

# Run all tests
cd Surypus && stack test

# Run a single test (by test name)
cd Surypus && stack test --test-arguments "--match 'VAT'"

# Run a single test file
cd Surypus && stack test --test-arguments "test/Test.hs"

# Watch mode (rebuild on changes)
cd Surypus && stack build --file-watch

# REPL for interactive development
cd Surypus && stack repl

# Typecheck without building
cd Surypus && stack ghc -- -fno-code

# Run hlint (if installed)
cd Surypus && hlint src/
```

```

---

## Running Tests

Tests use **Hspec** for unit tests and **QuickCheck** for property-based testing.

### Single Test Examples

```bash
# Run tests matching a pattern
stack test --match "VAT"

# Run specific spec
stack test --test-arguments "-m \"НДС 20%\""

# Run with verbose output
stack test --verbose

# Run QuickCheck properties
stack test --test-arguments "--quickcheck"
```

### Test Structure

Tests are in `Surypus/test/Test.hs`:
- `spec_vat_calculation` - VAT calculation tests
- `spec_accounting` - Double-entry bookkeeping tests
- `spec_inventory` - Stock/warehouse tests
- QuickCheck properties: `prop_vat_nonnegative`, `prop_price_with_vat_ge`

---

## Code Style Guidelines

### Language Standard
- **Haskell**: Use Haskell2010 (`default-language: Haskell2010` in .cabal)
- Enable warnings: `-Wall` (already set in stack.yaml for locals)

### Imports

```haskell
-- Group imports in this order:
import qualified Data.Text as T  -- External libraries
import qualified Data.Map as M
import Data.Text (Text)           -- Specific exports
import Data.Int (Int64)

-- Local imports
import Core.Tax
import DAL.Types
```

### Naming Conventions

| Element | Convention | Example |
|---------|------------|---------|
| Modules | PascalCase | `Core.Tax`, `DAL.Queries` |
| Types | PascalCase | `TaxRate`, `LedgerEntry` |
| Type aliases | PascalCase | `type Money = Decimal` |
| Functions | camelCase | `calcVAT`, `validateTaxRate` |
| Record fields | camelCase | `trId`, `trName`, `leDate` |
| Constructors | PascalCase | `PPOPT_SALES`, `Asset` |
| Type variables | camelCase | `a`, `m`, `f` |

### Record Syntax

```haskell
-- Use record syntax for data with multiple fields
data TaxRate = TaxRate
  { trId    :: Int64
  , trName  :: Text
  , trRate  :: Double
  , trFlags :: Int
  } deriving (Show, Eq)

-- Access fields directly (no lenses needed initially)
getRate :: TaxRate -> Double
getRate t = trRate t
```

### Type Definitions

```haskell
-- Use newtype for single-field wrappers with constraints
newtype Money = Money { unMoney :: Decimal }
  deriving (Eq, Num)

-- Use data for sum types with multiple constructors
data BillType 
  = PPOPT_GOODSRECEIPT
  | PPOPT_SALES
  | PPOPT_TRANSFER
  deriving (Eq, Show)

-- Use type aliases for domain concepts
type DocDate = Day
type GoodsID = Int
type BillID = Int
```

### Error Handling

```haskell
-- Use Either for recoverable errors
validateTaxRate :: TaxRate -> Either String TaxRate
validateTaxRate tr
  | trRate tr < 0 = Left "Tax rate cannot be negative"
  | trRate tr > 100 = Left "Tax rate cannot exceed 100%"
  | otherwise = Right tr

-- Use Maybe for optional values
findGoods :: GoodsID -> Maybe Goods

-- Pattern matching in do-blocks
case validateTaxRate rate of
  Left err -> logError err >> return Nothing
  Right r  -> processRate r
```

### Documentation

```haskell
-- Module header (required)
-- | Tax calculation module
module Core.Tax (calcVAT, calcTaxInclusive) where

-- Function docs (for public API)
-- | Calculate VAT amount from price and rate
-- | Returns: VAT amount >= 0 and <= price
calcVAT :: Double -> Double -> Double
calcVAT amount rate = amount * (rate / 100.0)
```

### Formatting

- **Indentation**: 2 spaces (no tabs)
- **Line length**: 100 characters max
- **Trailing whitespace**: Remove
- **Blank lines**: Single blank line between top-level definitions

### Refinement Types (LiquidHaskell)

For formal verification, use LiquidHaskell predicates:

```haskell
{-@ type NonNeg = {v:Double | v >= 0} @-}

{-@ calcVAT :: Double -> NonNeg -> NonNeg @-}
calcVAT :: Double -> Double -> Double
calcVAT amount rate = amount * (rate / 100.0)
```

### PostgreSQL Integration

Heavy computations should live in PostgreSQL:
- Use stored procedures for: `calc_vat()`, `calc_bill_totals()`, `get_lot_bounds()`
- Validate in Haskell, compute in SQL
- Use `hasql` library for type-safe queries

---

## File Organization

```
Surypus/
├── src/
│   ├── Core/           -- Domain modules (Tax, Goods, Accounting, etc.)
│   ├── DAL/            -- Database access layer
│   ├── Surypus/        -- Core utilities (Types, Z3, I18n)
│   ├── APIServer.hs    -- REST API (Scotty)
│   └── Reports.hs     -- Report generation
├── test/
│   ├── Test.hs        -- Main test suite
│   ├── Domain/        -- Domain-specific tests
│   ├── DB/            -- Integration tests
│   └── API/           -- API tests
└── stack.yaml
```

---

## Key Dependencies

- **base** >=4.12 && <5
- **text** - Text handling
- **time** - Date/time
- **uuid** - Unique identifiers
- **containers** - Data structures
- **hspec** - Testing framework
- **QuickCheck** - Property-based testing

---

## Development Workflow

1. Make changes in `src/`
2. Run `stack build` to check compilation
3. Run `stack test` to verify tests pass
4. Run `stack test --match "pattern"` for targeted testing
5. Use `stack repl` for interactive debugging

---

## Common Issues to Avoid

### Imports
- **NEVER** import `Double` from `GHC.Float` - it's already in Prelude
- Use `qualified Data.Text as T` (not `Data.Text as Data.Text`)
- Remove unused imports (causes warnings)

### Type Safety
- Use `Text` instead of `String` for user data
- Use `Int64` for database IDs
- Avoid `undefined` - use proper error handling

### Testing
- Always use `Text.pack` for string literals in tests: `T.pack "text"`
- Match record field order exactly when constructing values
- Import test dependencies in cabal file for both library and test-suite

---

## Architecture Principles

### Layer Separation
1. **Core/** - Domain logic (Tax, Accounting, Warehouse)
2. **DAL/** - Database access (Queries, Mutations, Types)
3. **Surypus/** - Utilities (Types, Z3, I18n)

### Key Invariants (to verify in code)
- VAT: result >= 0 and <= price
- Accounting: Σ Debit = Σ Credit
- Stock: Rest = Initial + Receipt - Issue

### Refinement Types (LiquidHaskell)
Use LiquidHaskell to prove critical properties:
```haskell
{-@ type NonNeg = {v:Double | v >= 0} @-}
{-@ calcVAT :: Double -> NonNeg -> NonNeg @-}
```
