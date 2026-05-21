# Phase 14: CRM Data Model - Pattern Map

**Mapped:** 2026-05-18
**Files analyzed:** ~80 Haskell source files across 4 packages
**Analogs found:** 8/8 target areas with concrete matches

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|---|---|---|---|---|
| `src/CRM.hs` | module (re-export aggregator) | - | `src/Inventory.hs` | exact |
| `src/CRM/Types.hs` | model (shared types) | request-response | `src/Inventory/Category.hs` + `surypus-common/src/Surypus/Types/Person.hs` | role-match |
| `src/CRM/Deal.hs` | model | CRUD | `src/Inventory/Goods.hs` + `src/Inventory/Lot.hs` | role-match |
| `src/CRM/Lead.hs` | model | CRUD | `src/Inventory/Brand.hs` + `src/HR/Person.hs` | role-match |
| `src/CRM/Contact.hs` | model | CRUD | `src/HR/Person.hs` + `src/Inventory/Manufacturer.hs` | role-match |
| `src/CRM/Pipeline.hs` | model | CRUD | `src/Inventory/Category.hs` (sum types + records) | role-match |
| `src/CRM/Activity.hs` | model | CRUD | `src/Inventory/Lot.hs` (record + sum types) | role-match |
| `surypus-api/src/Surypus/API/CRM.hs` | controller (API handlers) | request-response | **already exists** — extend | exact |
| `surypus-api/src/Surypus/API/Server.hs` | controller (routes) | request-response | already integrated — extend | exact |
| `src/Surypus/RBAC.hs` | authz | - | already exists — extend | exact |
| `test/Domain/CRMSpec.hs` | test | - | `test/Domain/GoodsSpec.hs` + `test/Domain/LocationSpec.hs` | role-match |
| `test/Integration/CRMSpec.hs` | test | - | `test/Integration/CrudSpec.hs` | role-match |

### Existing CRM Code Already Present
**Critically, a CRM module already exists at `surypus-api/src/Surypus/API/CRM.hs`** (270 lines) with:
- `Deal`, `DealInput`, `DealStage`, `Activity`, `ActivityInput`, `PipelineForecast` types
- `listDeals`, `createDeal`, `getDeal`, `updateDealStage`, `getPipelineForecast`, `listActivities` functions
- Direct Hasql SQL statements with row/param encoding
- Integrated in `Surypus.API.Server` at routes `/crm/deals`, `/crm/pipeline`, `/crm/.../activities`

**Phase 14 should refactor/extend this, not replace it from scratch.**

---

## Pattern Assignments

### `src/CRM/Types.hs` (model, CRUD)

**Analog 1:** `surypus-common/src/Surypus/Types/Person.hs` (lines 1-81)
**Analog 2:** `surypus-common/src/Surypus/Types/Common.hs` (lines 1-143)

**Imports pattern:**
```haskell
-- From: surypus-common/src/Surypus/Types/Person.hs lines 1-20
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE DuplicateRecordFields #-}

module Surypus.Types.Person
  ( Person (..),
    PersonType (..),
    PersonStatus (..),
    PersonInput (..),
    PersonSummary (..),
  )
where

import Data.Aeson (FromJSON (..), Options (..), ToJSON (..), defaultOptions, genericParseJSON, genericToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time.Clock (UTCTime)
import GHC.Generics (Generic)
import Surypus.Types.Common (camelTo2)
```

**Record type pattern** (Person.hs lines 22-38):
```haskell
data Person = Person
  { personId :: !Int64,
    personName :: !Text,
    personINN :: !Text,
    personKPP :: !(Maybe Text),
    personType :: !PersonType,
    personStatus :: !PersonStatus,
    personCreatedAt :: !UTCTime,
    personUpdatedAt :: !(Maybe UTCTime)
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON Person where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 6}

instance FromJSON Person where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = camelTo2 '_' . drop 6}
```

**Input type pattern** (Person.hs lines 54-67):
```haskell
data PersonInput = PersonInput
  { piName :: !Text,
    piINN :: !Text,
    piKPP :: !(Maybe Text),
    piPersonType :: !PersonType,
    piStatus :: !PersonStatus
  }
  deriving stock (Show, Eq, Generic)

instance ToJSON PersonInput where
  toJSON = genericToJSON defaultOptions {fieldLabelModifier = drop 2}

instance FromJSON PersonInput where
  parseJSON = genericParseJSON defaultOptions {fieldLabelModifier = drop 2}
```

**Sum type for enumeration** (Person.hs lines 40-52):
```haskell
data PersonType = Customer | Supplier | Employee | Partner
  deriving stock (Show, Eq, Generic)

instance ToJSON PersonType
instance FromJSON PersonType

data PersonStatus = PersonActive | PersonBlocked | PersonDeleted
  deriving stock (Show, Eq, Generic)

instance ToJSON PersonStatus
instance FromJSON PersonStatus
```

**Key naming conventions:**
- Record fields: `typeAbbreviationFieldName` e.g., `personId`, `piName`, `prId`
- Input types: Prefix with `Input` suffix or abbreviation e.g., `PersonInput`, `DealInput`
- Input field prefix: `pi` for PersonInput, `di` for DealInput
- Output/Response types: `XResponse` or `X` for reads
- Drop prefix for JSON serialization using `fieldLabelModifier` (e.g., `drop 2` for 2-char prefix, `drop 6` for `person`)

**Analog CamelCase helper:** `surypus-common/src/Surypus/Types/Common.hs` lines 136-143:
```haskell
camelTo2 :: Char -> String -> String
camelTo2 _ [] = []
camelTo2 c (x : xs) = toLower x : go xs
  where
    go [] = []
    go (y : ys)
      | isUpper y = c : toLower y : go ys
      | otherwise = y : go ys
```

---

### `src/CRM/Deal.hs` (model, CRUD)

**Analog:** `src/Inventory/Goods.hs` (lines 1-8) + `src/Inventory/Lot.hs` (lines 1-57) + `src/Inventory/Location.hs` (lines 1-37)

**Module export pattern** (Location.hs lines 1-2):
```haskell
-- | Location types - Warehouses and stores
module Inventory.Location where
```

Or with explicit export list (Lot.hs lines 2-6):
```haskell
-- | Lot types - Stock lots/batches
module Inventory.Lot
  ( Lot (..),
    LotStatus (..),
    LotFlags (..)
  ) where
```

**Domain type pattern** (Lot.hs lines 14-28):
```haskell
import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day, fromGregorian)

data Lot = Lot
  { lotId :: Int64,
    lotGoodsId :: Int64,
    lotLocationId :: Int64,
    lotQtty :: Double,
    lotCost :: Double,
    lotPrice :: Double,
    lotDate :: Day,
    lotExpiry :: Maybe Day,
    lotFlags :: Int,
    lotSerialNumber :: Maybe Text,
    lotSupplierId :: Maybe Int64,
    lotBillId :: Maybe Int64
  }
  deriving (Show, Eq)

-- | Lot status
data LotStatus
  = LSActive
  | LSClosed
  | LSExpired
  | LSReserved
  deriving (Show, Eq)

-- | Lot flags
data LotFlags = LotFlags
  { lfStrictSerial :: Bool,
    lfNegativeOk :: Bool,
    lfFifo :: Bool
  }
  deriving (Show, Eq)
```

**QuickCheck Arbitrary instance** (Lot.hs lines 46-57):
```haskell
instance Arbitrary Lot where
  arbitrary = do
    qtty <- suchThat arbitrary (>= 0)
    cost <- suchThat arbitrary (>= 0)
    price <- suchThat arbitrary (>= 0)
    pure $ Lot 0 0 0 qtty cost price (fromGregorian 2024 1 1) Nothing 0 Nothing Nothing Nothing

instance Arbitrary LotStatus where
  arbitrary = elements [LSActive, LSClosed, LSExpired, LSReserved]
```

---

### `src/CRM/Lead.hs` and `src/CRM/Contact.hs` (model, CRUD)

**Analog:** `src/HR/Person.hs` (lines 1-85)

**Record pattern with validation functions** (HR/Person.hs lines 18-42):
```haskell
data Person = Person
  { pId :: Int64,
    pCode :: Text,
    pName :: Text,
    pFullName :: Text,
    pShortName :: Text,
    pINN :: Text,
    pKPP :: Text,
    pOKPO :: Text,
    pOKVED :: Text,
    pLegalAddress :: Text,
    pAddress :: Text,
    pPhone :: Text,
    pFax :: Text,
    pEmail :: Text,
    pWWW :: Text,
    pPersonKindId :: Int64,
    pCategoryId :: Int64,
    pStatusId :: Int64,
    pParentId :: Int64,
    pOwnerId :: Int64,
    pRegisterDate :: Day,
    pFlags :: PersonFlags
  }
  deriving (Show, Eq)

data PersonKind
  = PKCompany
  | PKIndividual
  | PKEntrepreneur
  | PKBank
  | PKSupplier
  | PKCustomer
  | PKEmployee
  deriving (Show, Eq, Enum)

data PersonStatus = PSActive | PSInactive | PSBlocked | PSDeleted
  deriving (Show, Eq, Enum)
```

---

### `src/CRM.hs` (Re-export aggregator)

**Analog:** `src/Inventory.hs` (lines 1-10):
```haskell
-- | Inventory Domain - Re-exports all Inventory modules
module Inventory where

import Inventory.Goods
import Inventory.Location
import Inventory.Lot
import Inventory.Barcode
import Inventory.Tag2
import Inventory.TagValue
import Inventory.TagObject
```

Follow the exact same pattern:
```haskell
-- | CRM Domain - Re-exports all CRM modules
module CRM where

import CRM.Deal
import CRM.Lead
import CRM.Contact
import CRM.Pipeline
import CRM.Activity
import CRM.Types
```

---

### `surypus-api/src/Surypus/API/CRM.hs` (controller, request-response)

**CRITICAL: This file already exists (270 lines).** Phase 14 extends it or splits it.

**Analog:** The file itself (`surypus-api/src/Surypus/API/CRM.hs` lines 1-270)

**Existing structure to extend:**
```haskell
-- Lines 1-35: Module header, imports, types
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.CRM
  ( Deal(..)
  , DealInput(..)
  , DealStage(..)
  , Activity(..)
  , ...
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Aeson (ToJSON, FromJSON, ...)
import GHC.Generics (Generic)
import Control.Exception (try, SomeException)
import qualified Hasql.Session as Session
import qualified Hasql.Statement as Statement
import qualified Hasql.Decoders as D
import qualified Hasql.Encoders as E
import Data.Functor.Contravariant ((>$<))
import DAL.Database (Pool, usePool)
import Surypus.CoreTypes (QueryResult(..))
```

**Hasql CRUD pattern** (CRM.hs lines 104-131, listDeals):
```haskell
listDeals :: Pool -> IO (QueryResult [Deal])
listDeals pool = do
  let stmt = Statement.Statement
        "SELECT d.id, d.deal_name, d.deal_value, s.stage_name, \
        \  p.full_name, co.company_name, \
        \  d.expected_close_date::TEXT, d.priority, d.probability, d.is_active \
        \FROM crm_deals d \
        \LEFT JOIN crm_pipeline_stages s ON d.stage_id = s.id \
        \LEFT JOIN persons p ON d.person_id = p.id \
        \LEFT JOIN companies co ON d.company_id = co.id \
        \ORDER BY d.created_at DESC"
        ()
        (D.rowList $ Deal
          <$> D.column (D.nonNullable D.text)
          <*> D.column (D.nonNullable D.text)
          <*> D.column (D.nonNullable D.float8)
          <*> D.column (D.nonNullable D.text)
          <*> D.column (D.nullable D.text)
          <*> D.column (D.nullable D.text)
          <*> D.column (D.nullable D.text)
          <*> D.column (D.nonNullable D.text)
          <*> D.column (D.nonNullable D.float8)
          <*> D.column (D.nonNullable D.bool))
        True
  result <- try $ usePool pool $ Session.statement () stmt
  case result of
    Right deals -> return $ QuerySuccess deals
    Left (e :: SomeException) -> return $ QueryError (T.pack $ show e)
```

**Hasql INSERT with param encoder** (CRM.hs lines 133-165, createDeal):
```haskell
createDeal :: Pool -> DealInput -> IO (QueryResult Deal)
createDeal pool input = do
  let stmt = Statement.Statement
        "INSERT INTO crm_deals (...) \
        \VALUES (...$1, $2...) \
        \RETURNING id::TEXT, ..."
        ( E.param (E.nonNullable E.text) >$< (\(DealInput n _ _ _ _ _ p) -> n)
        <> E.param (E.nonNullable E.float8) >$< (\(DealInput _ v _ _ _ _ _) -> v)
        <> ...)
        (D.singleRow $ Deal
          <$> D.column (D.nonNullable D.text)
          <*> ...)
        True
  result <- try $ usePool pool $ Session.statement input stmt
  case result of
    Right deal -> return $ QuerySuccess deal
    Left (e :: SomeException) -> return $ QueryError (T.pack $ show e)
```

**Error handling pattern** — uses `try (SomeException)` around all DB operations returning `Either Text a`. No custom error handler; `QueryError` carries the message string.

---

### `surypus-api/src/Surypus/API/Server.hs` (controller, Servant route setup)

**Analog:** `surypus-api/src/Surypus/API/Server.hs` lines 92-111 (API type definition) + lines 113-132 (server implementation)

**Servant API type pattern** (Server.hs lines 92-111):
```haskell
type SurypusApi =
  "api" :> "v1" :> 
    ( "bills" :> Get '[JSON] [Bill]
      :<|> "bills" :> ReqBody '[JSON] BillInput :> Post '[JSON] Bill
      :<|> ...
      :<|> "crm" :> "deals" :> Get '[JSON] [CRM.Deal]
      :<|> "crm" :> "deals" :> ReqBody '[JSON] CRM.DealInput :> Post '[JSON] CRM.Deal
      :<|> "crm" :> "deals" :> Capture "id" Text :> Get '[JSON] CRM.Deal
      :<|> ...
    )
```

**Handler pattern** (Server.hs lines 162-174):
```haskell
crmDealsList :: Env -> Handler [CRM.Deal]
crmDealsList env = do
  result <- liftIO $ CRM.listDeals (envPool env)
  case result of
    QuerySuccess deals -> pure deals
    QueryError err -> throwError $ err500 {errBody = LBS.encodeUtf8 $ "CRM error: " <> TL.fromStrict err}

crmDealCreate :: Env -> CRM.DealInput -> Handler CRM.Deal
crmDealCreate env input = do
  result <- liftIO $ CRM.createDeal (envPool env) input
  case result of
    QuerySuccess deal -> pure deal
    QueryError err -> throwError $ err500 {errBody = LBS.encodeUtf8 $ "CRM error: " <> TL.fromStrict err}
```

**Error handling** — `throwError $ err500 {errBody = ...}` for generic errors, `throwError err404` for "Not Found" (Server.hs line 181).

---

### `src/Surypus/RBAC.hs` (authorization, request-response)

**Analog:** `src/Surypus/RBAC.hs` lines 1-174 (already exists — extend)

**Permission type pattern** (RBAC.hs lines 20-54):
```haskell
data Permission
  = PersonRead
  | PersonWrite
  | PersonDelete
  | GoodsRead
  | GoodsWrite
  | GoodsDelete
  | ...
  | AdminAccess
  deriving (Show, Eq, Enum, Bounded)
```

**For Phase 14, add CRM-specific permissions:**
```haskell
  | CRMLeadRead
  | CRMLeadWrite
  | CRMDealRead
  | CRMDealWrite
  | CRMContactRead
  | CRMContactWrite
```

**permissionToText / parsePermissionText pattern** (RBAC.hs lines 57-91):
```haskell
permissionToText :: Permission -> Text
permissionToText = \case
  PersonRead -> "person:read"
  ...
  CRMLeadRead -> "crm_lead:read"
  CRMLeadWrite -> "crm_lead:write"
  ...
```

**requirePermissionChecked** (RBAC.hs lines 169-174):
```haskell
requirePermissionChecked :: Int64 -> Permission -> Handler ()
requirePermissionChecked userId perm = do
  result <- liftIO $ requirePermission userId perm
  case result of
    Right () -> pure ()
    Left err -> throwError err403 {errBody = LBS.encodeUtf8 $ "Permission denied: " <> TL.fromStrict err}
```

**Authorization resolver** in `Surypus.API.Authorization` (lines 24-153) — add CRM routes:
```haskell
-- In requiredPermissionForPathMethod:
["crm", "deals"] -> Just $ case () of
  _ | isGet -> "crm_deal:read"
    | isPost -> "crm_deal:write"
    | otherwise -> "crm_deal:read"
```

---

## Shared Patterns

### Project Structure & Module Layout

**Source tree convention:**
```
src/
  Surypus/           -- Core framework (RBAC, JWT, CoreTypes, Error)
  DAL/               -- Data Access Layer (Types, Database, EventStore, Queries, Mutations)
  Inventory/         -- Domain: each sub-module is one entity (Goods, Stock, Location)
  HR/                -- Domain: Person, Types, Operations
  Service/           -- Business logic services
  API/               -- API types (API.hs, V1.hs, Types.hs, Server.hs)
  Infrastructure/    -- EventStore, Encryption, WebSocket
  Inventory.hs       -- Re-export aggregator for domain

surypus-common/src/Surypus/
  Types/             -- Shared types (Person, Goods, Stock, Auth, Common, etc.)
  Types.hs           -- Re-export aggregator
  Api.hs             -- Servant API type

surypus-api/src/Surypus/
  API/              -- Handlers (Persons, Goods, Bills, CRM, Dashboard, Server)
  DAL/              -- + Repo. Queries, Mutations
```

**CRM files should follow:**
- `src/CRM.hs` — re-export aggregator
- `src/CRM/Types.hs` — shared CRM types (like `Inventory/Types.hs`)
- `src/CRM/Deal.hs` — domain types (like `Inventory/Lot.hs` or `Inventory/Category.hs`)
- `src/CRM/Lead.hs` — domain types
- `src/CRM/Contact.hs` — domain types
- `src/CRM/Pipeline.hs` — domain types
- `src/CRM/Activity.hs` — domain types
- `surypus-api/src/Surypus/API/CRM.hs` — already exists (extend with additional operations)

### Hasql Statement Pattern (from surypus-api)

**Row decoder** (Queries.hs lines 78-87):
```haskell
personRowDecoder :: D.Row Person
personRowDecoder =
  Person
    <$> D.column (D.nonNullable D.int8)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nullable D.text)
    <*> D.column (D.nonNullable D.int2)
    <*> D.column (D.nonNullable D.int2)
```

**Field projection in encoders** (Mutations.hs lines 68-76):
```haskell
personInputEncoder :: E.Params PersonInput
personInputEncoder =
  (piCode >$< E.param (E.nullable E.text))
    <> (piName >$< E.param (E.nonNullable E.text))
    <> (piINN >$< E.param (E.nullable E.text))
    <> (piKPP >$< E.param (E.nullable E.text))
    <> (piPersonType >$< E.param (E.nonNullable E.int2))
    <> (piStatus >$< E.param (E.nonNullable E.int2))
```

**Preparable helper** (Queries.hs lines 39-40):
```haskell
preparable :: T.Text -> E.Params params -> D.Result result -> Statement params result
preparable sql encoder decoder = Statement (TE.encodeUtf8 sql) encoder decoder True
```

**Query execution** (Queries.hs lines 306-317):
```haskell
getPersons :: Pool -> IO (QueryResult [Person])
getPersons pool = do
  let stmt = preparable "SELECT id, name FROM persons ORDER BY id" E.noParams (D.rowList personRowDecoder)
  res <- use pool $ Session.statement () stmt
  case res of
    Right rows -> pure $ QuerySuccess rows
    Left err -> pure $ QueryError (T.pack $ show err)
```

**Mutation helper** (Mutations.hs lines 49-55):
```haskell
runMutationReturningId :: Pool -> Text -> E.Params params -> params -> Text -> IO (QueryResult MutationResult)
runMutationReturningId pool sql encoder payload successMessage = do
  let stmt = unpreparable sql encoder mutationIdDecoder
  res <- use pool $ Session.statement payload stmt
  case res of
    Right rid -> pure $ QuerySuccess (MutationResult True (Just rid) successMessage)
    Left err -> pure $ QueryError (T.pack (show err))
```

### QueryResult Type (DAL/Types.hs lines 63-69)
```haskell
data QueryResult a
  = QuerySuccess a
  | QueryError Text
  deriving stock (Show, Eq, Generic, Functor)

instance ToJSON a => ToJSON (QueryResult a)
instance FromJSON a => FromJSON (QueryResult a)
```

### Validation Pattern (Surypus/Validation.hs lines 31-137)
```haskell
data ValidationError
  = EmptyName
  | InvalidINN
  | InvalidKPP
  | InvalidAmount
  | InvalidDate
  | FieldTooLong Text
  | FieldRequired Text
  deriving (Show, Eq)

validateGoodsInput :: Text -> Text -> Either ValidationError ()
validateGoodsInput name _article
  | T.null name = Left (FieldRequired "name")
  | otherwise = Right ()
```

### Test Pattern (test/Domain/GoodsSpec.hs)
```haskell
{-# LANGUAGE OverloadedStrings #-}
module Domain.GoodsSpec where

import Test.Hspec
import Domain.Goods

spec :: Spec
spec = do
  describe "Goods" $ do
    it "creates goods with required fields" $ do
      let g = Goods { ... }
      goodsName g `shouldBe` "Test Product"
```

### Dependencies Available (in Surypus and surypus-api)
From `Surypus.cabal`: `hasql >=1.6`, `hasql-pool >=0.10`, `aeson >=2.2`, `lens >=5.2`, `servant >=0.20`, `servant-server >=0.20`, `hspec >=2.11`, `QuickCheck >=2.14`, `text`, `time`, `uuid`, `containers`, `Decimal >=0.5`
From `surypus-api.cabal`: `servant`, `servant-server`, `wai`, `warp`, `hasql`, `hasql-pool`, `websockets`, `uuid`, `aeson`, `time`, `fast-logger`

## No Analog Found

| File | Role | Data Flow | Reason |
|------|------|-----------|--------|
| `src/CRM/Pipeline.hs` | model | CRUD | No existing pipeline stage model — use sum type pattern from Inventory/Category.hs |
| `src/CRM/Activity.hs` | model | CRUD | No existing activity model — use record pattern from Inventory/Lot.hs |

## Metadata

**Analog search scope:** `/home/domini/src/My/Surypus/src/` (all .hs files) + `/home/domini/src/My/Surypus/surypus-api/src/` + `/home/domini/src/My/Surypus/surypus-common/src/` + `/home/domini/src/My/Surypus/test/`
**Files scanned:** ~80 Haskell source files
**Pattern extraction date:** 2026-05-18
