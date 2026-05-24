# Coding Conventions

**Analysis Date:** 2026-05-24

## Language & Compiler

**Default Language:** Haskell2010 (set in all `.cabal` files via `default-language: Haskell2010`)

**Compiler:** GHC via Stack (resolver `lts-22.21`, GHC 9.6.5)

**GHC Options:**
- `-Wall -Wcompat` on all library and test targets (`stack.yaml` line 20)
- `surypus-common` adds: `-Widentities -Wincomplete-record-updates -Wincomplete-uni-patterns -Wmissing-export-lists -Wmissing-home-modules -Wpartial-fields -Wredundant-constraints -fhide-source-paths` (`surypus-common.cabal` lines 43-50)
- API executable adds: `-threaded -rtsopts -with-rtsopts=-N -O2` (`surypus-api.cabal` line 103)

## Language Pragmas

**Most common pragmas (appear across source):**

| Pragma | Usage | Example files |
|--------|-------|---------------|
| `OverloadedStrings` | Universal — nearly every `.hs` file | All modules |
| `RecordWildCards` | Destructuring in `ToJSON` instances, pattern matching | `System/Logger.hs`, `Surypus/JWT.hs` |
| `LambdaCase` | `\case` syntax for pattern matching on enums | `Surypus/RBAC.hs` |
| `GeneralizedNewtypeDeriving` | Deriving `Num`, `Fractional` on newtypes | `Surypus/CoreTypes.hs` |
| `DeriveGeneric` | Automatic `Generic` derivation for JSON | `DAL/Types.hs`, `CRM/Types.hs` |
| `DuplicateRecordFields` | Multiple types sharing field names (e.g., `id`, `name`) | `DAL/Types.hs` |
| `DerivingStrategies` | Explicit `deriving stock` vs `deriving newtype` | `DAL/Types.hs` |
| `ScopedTypeVariables` | Type annotations in `where` clauses | `Surypus/JWT.hs` |
| `ImportQualifiedPost` | `import qualified Foo as F` style | `Surypus/JWT.hs` |
| `DeriveFunctor` | Deriving `Functor` for parameterized types | `DAL/Types.hs` |

**Liquid Haskell annotations** used in `Finance/Accounting.hs`:
```haskell
{-@ LIQUID "--reflection" @-}
{-@ LIQUID "--ple"        @-}
```

## Naming Patterns

**Files:**
- PascalCase directory and file names matching module names: `System/Auth.hs`, `CRM/Contact.hs`, `DAL/Types.hs`
- One module per file
- Test files use `*Spec.hs` suffix (e.g., `Domain/CRMSpec.hs`)

**Modules:**
- Hierarchical dot notation: `System.Auth`, `CRM.Contact`, `DAL.Types`, `Service.InventoryService`
- Sub-package top-level modules: `Surypus.Core`, `Surypus.RBAC`, `Surypus.JWT`
- Re-export aggregator modules: `Surypus.hs` re-exports `Surypus.Core`, `Surypus.CoreTypes`, `Surypus.JWT`, `Surypus.RBAC`, `DAL.Types`, `DAL.Database`, `DAL.EventStore`

**Types:**
- PascalCase: `User`, `LogEntry`, `InventoryDoc`, `Permission`, `StockMovement`
- Sum types with short descriptive constructors: `IDTReceipt | IDTIssue | IDTTransfer | IDTWriteOff | IDTAdjustment`
- Algebraic data types for enums: `LogLevel = Debug | Info | Warn | Error | Critical`
- Wrapper newtypes with exposed accessor/unwrapper: `newtype NonNeg = NonNeg Decimal` with `unNonNeg`

**Record Fields:**
- Short prefix convention — field names use 1-4 character prefixes derived from the type name:
  - `User` → `uId`, `uLogin`, `uName`, `uGroupId`, `uFlags` (`System/Auth.hs`)
  - `Contact` → `cId`, `cFirstName`, `cLastName`, `cEmail` (`CRM/Contact.hs`)
  - `InventoryDoc` → `idId`, `idDocType`, `idStatus`, `idDate`, `idLines` (`Service/InventoryService.hs`)
  - `StockMovement` → `smGoodsId`, `smFromLocation`, `smToLocation`, `smQty` (`Service/InventoryService.hs`)
  - `LogEntry` → `logTimestamp`, `logLevel`, `logSource`, `logMessage`, `logContext` (`System/Logger.hs`)
  - `Config` → `cfgId`, `cfgKey`, `cfgValue`, `cfgType` (`System/Config.hs`)
- In `DAL/Types.hs`, the prefix convention uses full words for Input types (e.g., `biCode`, `piName`, `giCode`) vs abbreviated for entity fields (e.g., `billId`, `personName`, `goodsId`)

**Functions:**
- camelCase throughout: `validatePassword`, `isSessionExpired`, `generateTokenPair`, `calculateStockBalance`, `postInventoryDoc`
- Smart constructors: `mkNonNeg`, `mkLedgerEntry`, `mkStock`, `mkTransaction`
- Boolean predicates: `isSessionExpired`, `validateStock`
- Accessor functions for newtypes: `unDecimal`, `unNonNeg`

**Variables:**
- camelCase
- Abbreviated parameter names for small scopes: `db`, `p`, `g`, `l`, `s`

## Module Structure

**Standard layout (observed consistently):**

```haskell
-- | Haddock module header
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE OptionalPragma #-}
module Module.Name
  ( -- * Section
    exportedName,
    anotherExport
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import External.Dependency (thing)

-- | Haddock for type
data MyType = MyType
  { mtField :: Text
  , mtOther :: Int
  } deriving (Show, Eq)

-- | Haddock for function
myFunction :: Text -> IO ()
myFunction arg = do
  ...
```

**Export lists:**
- Explicit export lists on all modules
- Grouped with `-- * Section` comments: `Service/Service.hs`, `DAL/Types.hs`
- Re-export modules listed with `module X` form: `Surypus/Core.hs`
- Format: one export per line, comma at end, indented 2 spaces

**Import organization:**
- Standard library imports first (`Prelude`, `Data.*`, `Control.*`, `System.*`)
- Third-party library imports next (`Data.Aeson`, `Test.Hspec`, `Servant`)
- Project-local imports last (`DAL.Types`, `Surypus.JWT`)
- `qualified` imports use single-letter aliases by convention: `import qualified Data.Text as T`, `import qualified Data.Map.Strict as Map`
- Some modules use `import qualified Data.Text.Lazy as TL`, `import qualified Data.Text.Lazy.Encoding as LBS`

## Code Style

**Formatting:**
- Tool: `stylish-haskell` (configured in `Makefile` line 160)
- Run via: `make format` → `find src -name "*.hs" -exec stylish-haskell -i {} \;`

**Linting:**
- Tool: `hlint` (configured in `.hlint.yaml` at project root)
- Run via: `make lint` → `hlint src/`
- Active hint groups:
  - `dollar` — suggests `$` reductions
  - `generalise` — suggests `map` → `fmap`, `++` → `<>`
  - `partial` — warns on partial functions
  - `future` — future-compatible suggestions
  - `extra` — extra hints
  - `use-lens` — lens usage hints
  - `use-th-quotes` — template Haskell quotes
- Hint ignores for false positives in specific modules (`.hlint.yaml` lines 78-87)

**Record construction style:**
- Always explicit record syntax with trailing commas:
```haskell
Contact
  { cId = cid,
    cFirstName = firstName,
    cLastName = lastName
  }
```

**Record update style:**
```haskell
let updated = person { pName = T.pack "Updated Name" }
```

**Where clauses / local bindings:**
- `where` blocks used for helper functions in `let`-less style
- Helper functions defined in `where` block with same indentation as body

## Error Handling

**Patterns observed:**

1. **`Either Text` for fallible operations** — most common pattern:
```haskell
postInventoryDoc :: IEI.InventoryEventStore -> (IEI.InventoryEvent -> IO ()) -> InventoryDoc -> IO (Either Text ())
```
(`Service/InventoryService.hs`)

2. **Custom error ADTs:**
```haskell
data JWTError = JWTExpired | JWTInvalid | JWTMissing | JWTMalformed
```
(`Surypus/JWT.hs`)

```haskell
data ValidationError
  = RequiredFieldMissing Text
  | InvalidFormat Text Text
  | OutOfRange Text Double (Double, Double)
  | DuplicateKey Text
  | CustomError Text
```
(`System/Validation.hs`)

3. **Smart constructors returning `Maybe`** — validation via returning `Nothing` for invalid states:
```haskell
mkNonNeg :: Decimal -> Maybe NonNeg
mkNonNeg d
  | d >= 0 = Just (NonNeg d)
  | otherwise = Nothing
```
(`Surypus/CoreTypes.hs`)

```haskell
mkLedgerEntry :: ... -> Maybe LedgerEntry
mkLedgerEntry lid date acc desc debitAmt creditAmt docRef
  | debitAmt < 0 = Nothing
  | creditAmt < 0 = Nothing
  | otherwise = Just $ ...
```
(`Finance/Accounting.hs`)

4. **Validation returning `Either [ValidationError]`**:
```haskell
validateTransaction :: Transaction -> Either Text Transaction
validateTransaction tx@Transaction {txEntries = entries}
  | null entries = Left "Transaction must have at least one entry"
  | totalDebit /= totalCredit = Left "Transaction unbalanced..."
  | otherwise = Right tx
```
(`Finance/Accounting.hs`)

5. **Servant `Handler` errors via `throwError`**:
```haskell
requirePermissionChecked :: Int64 -> Permission -> Handler ()
requirePermissionChecked userId perm = do
  result <- liftIO $ requirePermission userId perm
  case result of
    Right () -> pure ()
    Left err -> throwError err403 {errBody = ...}
```
(`Surypus/RBAC.hs`)

6. **IO error propagation** — `IO` actions that can fail use `Either Text` within IO, not exceptions:
```haskell
case sequence res of
  Left err -> pure $ Left err
  Right _ -> pure $ Right ()
```
(`Service/InventoryService.hs`)

## Logging

**Framework:** Custom in-memory logger via `STM` `TVar` (`System/Logger.hs`)

**Log levels:** `Debug | Info | Warn | Error | Critical`

**Pattern:**
```haskell
writeLogMessage :: Logger -> LogLevel -> Text -> Text -> [(Text, Text)] -> IO ()
writeLogMessage (Logger var) level source msg context = do
  entry <- LogEntry <$> getCurrentTime <*> pure level <*> pure source <*> pure msg <*> pure context
  atomically $ do
    entries <- readTVar var
    writeTVar var (entry : entries)
```

**JSON serialization:**
- `ToJSON` instances for log types using `RecordWildCards`:
```haskell
instance ToJSON LogEntry where
  toJSON LogEntry {..} =
    object
      [ "timestamp" .= logTimestamp,
        "level" .= logLevel,
        ...
      ]
```

## Comments

**Haddock style (`-- |`):**
- Used for all top-level exports: modules, types, functions, fields
- Module headers describe purpose
- Function docs can include usage examples in `@` blocks (`Service/Service.hs` lines 16-28)

**Block comments (`{- | -}`):**
- Used sparingly for module-level docs spanning multiple lines (`DAL/Database.hs` line 2)

**Inline comments (`--`):**
- Used for parameter descriptions, invariant notes, TODOs
- `-- |` for Haddock-attached comments
- `--` for internal notes

**TODO comments found:**
- `-- TODO: Query database for user roles and permissions` (`Surypus/RBAC.hs` line 152)

## JSON Serialization

**Two approaches used:**

1. **Derived via `GHC.Generics` (most common):**
```haskell
data Bill = Bill { ... }
  deriving stock (Show, Eq, Generic)
instance ToJSON Bill
instance FromJSON Bill
```
(`DAL/Types.hs` — used throughout for all API types)

2. **Manual via `RecordWildCards` and `object`** (for log types):
```haskell
instance ToJSON LogEntry where
  toJSON LogEntry {..} = object [ ... ]
```
(`System/Logger.hs`)

## Type Class Patterns

**Service class pattern** (`Service/Service.hs`):
```haskell
class Service s where
  getPool :: s -> Pool

newtype PoolService s = PoolService {unPoolService :: Pool}
instance Service (PoolService s) where
  getPool = unPoolService
```

**Arbitrary instances for QuickCheck** (`CRM/Contact.hs`):
```haskell
instance Arbitrary Contact where
  arbitrary = do
    cid <- arbitrary
    firstName <- T.pack <$> suchThat arbitrary (not . null)
    ...
    pure Contact { cId = cid, ... }
```

## Data Patterns

**Record syntax for product types** — all data types use named fields:
```haskell
data Stock = Stock
  { sGoodsId :: Int64,
    sLocationId :: Int64,
    sQtty :: Double,
    ...
  }
```

**Sum types for enumerations:**
```haskell
data Permission
  = PersonRead
  | PersonWrite
  | ...
  deriving (Show, Eq, Enum, Bounded)
```
(`Surypus/RBAC.hs`)

**Newtypes for type safety:**
```haskell
newtype Decimal = Decimal Double
  deriving (Show, Eq, Num, Ord, Fractional)
  
newtype NonNeg = NonNeg Decimal
  deriving (Show, Eq, Ord)
```

**Strict fields (`!`) on API-facing data types** (`DAL/Types.hs`):
```haskell
data Bill = Bill
  { billId :: !Int64,
    billCode :: !(Maybe Text),
    ...
  }
```

---

*Convention analysis: 2026-05-24*
