# Testing Patterns

**Analysis Date:** 2026-05-24

## Test Framework

**Runner:** `hspec` (version 2.11+, via `Surypus.cabal` line 187)

**Config files:**
- `Surypus.cabal` — test suite `surypus-test` (lines 202-219)
- `surypus-api/surypus-api.cabal` — test suite `surypus-api-test` (lines 71-90)
- `surypus-common/surypus-common.cabal` — test suite `surypus-common-test` (lines 52-59)
- `.hlint.yaml` — hlint configuration

**Run Commands:**
```bash
stack test                             # Run all test suites
stack test surypus-test                # Run main package tests
stack test surypus-api-test            # Run API package tests
make test-unit                         # stack test
make test-integration                  # stack test test/Integration/...
```

**Auto-discovery:** `surypus-api/test/Spec.hs` uses `hspec-discover`:
```haskell
{-# OPTIONS_GHC -F -pgmF hspec-discover #-}
```
(`surypus-api/test/Spec.hs`)

## Test Suite Configuration

### Main Package (`Surypus.cabal` lines 202-219)
```
test-suite surypus-test
  type: exitcode-stdio-1.0
  hs-source-dirs: test
  main-is: Test.hs
  build-depends: base, Surypus, hspec, QuickCheck, text, time, aeson, bytestring, hasql, hasql-pool, stm, containers
  default-language: Haskell2010
```

### API Package (`surypus-api.cabal` lines 71-90)
```
test-suite surypus-api-test
  type: exitcode-stdio-1.0
  main-is: Spec.hs
  build-depends: base, surypus-api, hspec, hspec-core, text, jose, lens, bytestring, aeson, time
  hs-source-dirs: test
  ghc-options: -Wall -Wcompat
```

### Common Package (`surypus-common.cabal` lines 52-59)
```
test-suite surypus-common-test
  type: exitcode-stdio-1.0
  main-is: Test.hs
  hs-source-dirs: test
```

## Test File Organization

**Location:**
- `test/` at project root — main test directory
- `surypus-api/test/` — API package tests
- `surypus-common/test/` — common package tests
- `Surypus/test/` — secondary test directory for Surypus sub-package

**Naming:**
- Spec modules: `*Spec.hs` (e.g., `Domain/CRMSpec.hs`, `QuickCheckInvariantsSpec.hs`)
- Test modules: `*Test.hs` (e.g., `Test.hs`, `AdditionalTests.hs`, `NewtypeGuardsTest.hs`)
- Fixture modules: `Fixtures.hs`, `TestFixtures.hs`, `RBACFixtures.hs`
- Helper modules: `TestHelpers.hs`, `MoreAssertLike.hs`, `MakeTest.hs`

**Directory structure:**
```
test/
├── Main.hs                                  # Test entry point (standalone)
├── Test.hs                                  # Main test suite entry
├── Runner.hs                                # Aggregated spec runner
├── App.hs                                   # Test application setup
├── API/
│   ├── HealthSpec.hs                        # API health endpoint tests
│   ├── ServerSpec.hs                        # API server tests
│   ├── SwaggerSpec.hs                       # Swagger schema tests
│   ├── RBACSpec.hs                          # RBAC endpoint tests
│   └── ProcurementSpec.hs                   # Procurement API tests
├── DAL/
│   ├── DBSpec.hs                            # In-memory database unit tests
│   ├── TypesSpec.hs                         # Type serialization tests
│   ├── IntegrationSpec.hs                   # Integration tests
│   ├── EventStoreSpec.hs                    # Event store tests
│   ├── Fixtures.hs                          # Test data factories
│   └── FixturesSpec.hs                      # Fixture tests
├── DB/
│   └── RepositoriesSpec.hs                  # Repository tests
├── Domain/
│   ├── CRMSpec.hs                           # CRM domain tests
│   ├── PersonSpec.hs                        # Person domain tests
│   ├── BillSpec.hs                          # Bill domain tests
│   ├── GoodsSpec.hs                         # Goods domain tests
│   ├── PayrollSpec.hs                       # Payroll domain tests
│   ├── HRSpec.hs                            # HR domain tests
│   ├── HRPropertySpec.hs                    # HR property-based tests
│   └── ...
├── Integration/
│   ├── CrudSpec.hs                          # CRUD integration tests
│   ├── NegativeSpec.hs                      # Error path tests
│   ├── PropertySpec.hs                      # Property-based integration tests
│   ├── ValidationSpec.hs                    # Validation integration tests
│   └── PerformanceSpec.hs                   # Performance benchmarks
├── Inventory/
│   ├── StockSpec.hs                         # Stock logic tests
│   ├── GoodsSpec.hs                         # Goods logic tests
│   └── WarehouseSpec.hs                     # Warehouse logic tests
├── HR/
│   ├── PersonSpec.hs                        # HR person tests
│   └── OperationsSpec.hs                    # HR operations tests
├── Phase2Phase3/                            # Phase-specific test suites
│   ├── AccountingEventsSpec.hs
│   ├── AccountingReadModelSpec.hs
│   ├── AccountingEventStoreSpec.hs
│   ├── ReadModelCacheSpec.hs
│   └── AcceptanceSpec.hs
├── QuickCheckInvariantsSpec.hs              # Consolidated property tests
├── RBACSpec.hs                              # RBAC unit tests
├── RBACCanonSpec.hs                         # Canonical RBAC tests
├── ConfigSpec.hs                            # Configuration tests
├── ObservabilitySpec.hs                     # Observability tests
├── ConcurrencySpec.hs                       # Concurrency tests
├── MigrationDryRunSpec.hs                   # Migration dry-run tests
├── NewtypeGuardsTest.hs                     # Newtype validation tests
├── AdditionalTests.hs                       # Supplementary tests
├── TestFixtures.hs                          # Shared fixture records
└── TestHelpers.hs                           # Shared test helpers
```

## Test Structure

**Suite organization (standard pattern):**

```haskell
{-# LANGUAGE OverloadedStrings #-}
module Domain.CRMSpec where

import Test.Hspec
import Test.QuickCheck
import CRM.Contact

spec :: Spec
spec = do
  describe "Contact" $ do
    it "creates contact with required fields" $ do
      let c = Contact { ... }
      cFirstName c `shouldBe` "John"

    it "generates valid random contacts" $ property $
      \c -> not (T.null (cFirstName c))
```
(`Domain/CRMSpec.hs`)

**Main entry patterns:**

1. **Simple aggregator** (`test/Main.hs`):
```haskell
module Main where
import Test.Hspec
import Domain.TypesSpec

main :: IO ()
main = hspec $ do
  describe "Domain Types" typesSpec
```

2. **Multi-spec aggregator** (`test/Runner.hs`):
```haskell
module Main where
import Test.Hspec
import qualified RBACCanonSpec as RBACCanon
import qualified ObservabilitySpec as Observability

main :: IO ()
main = hspec spec

spec :: Spec
spec = do
  RBACCanon.spec
  Observability.spec
  ...
```

3. **Inline tests** (`test/Test.hs`):
```haskell
module Main where
import Test.Hspec

main :: IO ()
main = hspec $ do
  describe "Integration Tests" $ do
    describe "API Endpoints" $ do
      it "POST /v1/login authenticates admin" $ True `shouldBe` True
```

4. **hspec-discover** (`surypus-api/test/Spec.hs`):
```haskell
{-# OPTIONS_GHC -F -pgmF hspec-discover #-}
```

## Assertion Patterns

**Most common assertions (692 total uses in test files):**

- `shouldBe` — equality assertion (dominant pattern)
- `shouldSatisfy` — predicate assertion
- `shouldContain` — list/set membership
- `shouldMatch` — regex matching (occasional)
- `shouldRespondWith` — WAI response assertion
- `pending` / `pendingWith` — placeholder tests
- `expectationFailure` — manual failure with message
- `fail` — direct failure (used in case branches)

**Example patterns:**

```haskell
-- Equality
personsCount `shouldBe` 3
pName p `shouldBe` T.pack "Company A"

-- Booleans
result `shouldBe` True
found `shouldBe` Nothing

-- Satisfaction
result `shouldSatisfy` isLeft
stError state `shouldSatisfy` isJust

-- List containment
names `shouldContain` "Счёт-фактура"
length type1Persons `shouldBe` 2

-- Case analysis
case result of
  Just p -> pName p `shouldBe` T.pack "Company A"
  Nothing -> fail "Should find person with ID 1"
```

## QuickCheck / Property Testing

**Framework:** `Test.QuickCheck` (via hspec integration)

**Patterns:**

1. **Inline property tests** with `Test.Hspec.QuickCheck (prop)`:
```haskell
import Test.Hspec.QuickCheck (prop)

main :: IO ()
main = hspec $ do
  describe "Payroll invariants" $ do
    prop "net salary ≥ 0" prop_calcNetSalaryNonNeg
    prop "income tax ≥ 0" prop_calcIncomeTaxNonNeg
```
(`QuickCheckInvariantsSpec.hs`)

2. **Property functions with `property` wrapper:**
```haskell
spec :: Spec
spec = do
  describe "Contact" $ do
    it "generates valid random contacts" $ property $
      \c -> do
        not (T.null (cFirstName c)) `shouldBe` True
        not (T.null (cLastName c)) `shouldBe` True
```
(`Domain/CRMSpec.hs`)

3. **Standalone property declarations:**
```haskell
prop_bill_post_total_equals_sum_of_lines :: Bill -> Property
prop_bill_post_total_equals_sum_of_lines _ = property True
```
(`TestHelpers.hs`)

4. **`forAll` with generators:**
```haskell
prop_calcNetSalaryNonNeg :: Property
prop_calcNetSalaryNonNeg =
  forAll (choose (0.0, 10000000)) $ \salary ->
    calcNetSalaryFromGross salary >= 0
```
(`QuickCheckInvariantsSpec.hs`)

5. **`Arbitrary` instances** for domain types:
```haskell
instance Arbitrary Contact where
  arbitrary = do
    cid <- arbitrary
    firstName <- T.pack <$> suchThat arbitrary (not . null)
    pure Contact { cId = cid, ... }
```
(`CRM/Contact.hs`)

**Property test categories found:**
- Payroll invariants (net salary ≥ 0, taxes non-negative, net ≤ gross)
- Tax bracket calculations (progressive income tax, social tax cap)
- Year-end bonus formulas
- Vacation day calculations
- CRM type invariants (deal value non-negative, probability 0-100)
- Round-trip properties (field preservation)

## Fixtures and Factories

**Pattern:**

In `Test/DAL/Fixtures.hs` — factory functions for in-memory database tests:

```haskell
personFactory :: Int64 -> String -> Person
personFactory id name = PersonStub
  { pId = id
  , pCode = Just (T.pack $ "P" ++ show id)
  , pName = T.pack name
  , pINN = Just (T.pack $ "INN" ++ show id)
  , ...
  }

goodsFactory :: Int64 -> String -> Goods
goodsFactory id name = GoodsStub { ... }

locationFactory :: Int64 -> String -> Location
locationFactory id name = LocationStub { ... }

stockFactory :: Int64 -> Int64 -> Int64 -> Double -> Double -> Stock
stockFactory id goodId locId qty resrvQty = StockStub { ... }
```

**Scenario factories:**
```haskell
createRealisticScenario :: IO Database
createRealisticScenario = do
  db <- newDatabase
  mapM_ (insertPerson db) [personFactory 1 "Company A", ...]
  mapM_ (insertGoods db) (createTestGoods 10)
  ...
  return db
```
(`Test/DAL/Fixtures.hs`)

**Cleanup helpers:**
```haskell
cleanPersons :: Database -> IO ()
cleanPersons db = do
  persons <- readIORef (dbPersons db)
  mapM_ (deletePerson db . pId) persons
```
(`Test/DAL/Fixtures.hs`)

**Shared fixture records:**
```haskell
data Fixtures = Fixtures
  { fixturePersonId :: Int,
    fixtureGoodsId :: Int,
    ...
  }

placeholderFixtures :: Fixtures
placeholderFixtures = Fixtures { fixturePersonId = 1, ... }
```
(`TestFixtures.hs`)

**Test application setup** (`test/App.hs`):
```haskell
mkApp :: IO Application
mkApp = do
  let jwtSecret = "surypus-test-secret-key-2024" :: Text
  dbCfg <- databasePoolConfigFromEnv
  pool <- createDatabasePool dbCfg
  runMigrations pool
  ...
  return metricsApp
```

## Mocking

**Approach:** No formal mocking framework. The project uses:
1. **In-memory database** (`DAL.DB` with `IORef` backing) for unit tests
2. **Stub implementations** for external services (e.g., `requirePermission` in `Surypus/RBAC.hs`)
3. **Test doubles** via factory functions creating stub data types

**Example mock patterns:**

```haskell
-- In-memory database for testing
db <- newDatabase   -- Creates IORef-backed in-memory state
insertPerson db person
count <- countPersons db
count `shouldBe` 1

-- Stub permission check
checkAdminStatus userId = pure False

-- Stub token validation
validateRefreshToken _cfg token = ...
```

## WAI Integration Testing

**Framework:** `hspec-wai` (used in `API/HealthSpec.hs`)

```haskell
import Test.Hspec.Wai
import Test.MakeTest (makeApp)

spec :: Spec
spec = with makeApp $ do
  describe "GET /api/v1/health" $ do
    it "returns 200" $ do
      get "/api/v1/health" `shouldRespondWith` 200
    it "response contains status and db fields" $ do
      r <- get "/api/v1/health"
      let mb = A.decode (responseBody r) :: Maybe Value
      ...
```

## Test Types

### Unit Tests
- **Scope:** Domain logic, types, validation, calculations
- **Location:** `test/Domain/`, `test/DAL/`, `test/HR/`, `test/Inventory/`
- **Pattern:** Pure functions tested with `shouldBe`, record construction/field access
- **Database:** In-memory (`IORef`) — no external dependencies
- **Example:** `Domain/CRMSpec.hs`, `DAL/DBSpec.hs`, `HR/OperationsSpec.hs`

### Integration Tests
- **Scope:** API endpoints, database interactions, multi-entity workflows
- **Location:** `test/Integration/`, `test/API/`
- **Pattern:** `with makeApp` for WAI testing, fixture-based database setup
- **Database:** Requires PostgreSQL (via `hasql` pool) or in-memory stubs
- **Example:** `Integration/CrudSpec.hs`, `API/HealthSpec.hs`, `Integration/InventoryLifecycleSpec.hs`

### Property-Based Tests
- **Scope:** Invariants over domain logic (payroll, tax, stock, CRM)
- **Location:** `QuickCheckInvariantsSpec.hs`, `Domain/HRPropertySpec.hs`, `Integration/PropertySpec.hs`
- **Pattern:** `prop` helper from `Test.Hspec.QuickCheck`, `property` wrapper, `forAll` with generators
- **Example:** `QuickCheckInvariantsSpec.hs` — 14 property tests across payroll, social tax, income tax

### Placeholder / Pending Tests
- Many tests use `pending` or `pendingWith` stubs for unimplemented scenarios
- **Example:** `APITests.hs` — 20+ tests all using `pending`

## Coverage

**Requirements:** Not explicitly enforced (no coverage target in cabal files or Makefile)

**View Coverage:**
```bash
# Not configured in project
```

## CI/CD

**Testing runs via:** `make test` → `stack test`

**Database:** Docker Compose (`docker/docker-compose.yml`) provides PostgreSQL for integration tests

## Common Patterns

**Async Testing:**
Tests run in `IO` monad via hspec — no explicit async testing utilities observed beyond basic STM usage:
```haskell
it "creates a new database with test data" $ do
  db <- newDatabase
  personsCount <- countPersons db
  personsCount `shouldBe` 3
```

**Error Testing:**
```haskell
it "returns 404 for non-existent entity" $ do
  True `shouldBe` True   -- Placeholder

it "should return Nothing when finding non-existent person" $ do
  db <- newDatabase
  person <- findPersonById db 9999
  person `shouldBe` Nothing
```

**Crud Testing Pattern** (repeated across entities):
```haskell
describe "Person CRUD operations" $ do
  it "should insert a new person" $ do ...
  it "should find a person by ID" $ do ...
  it "should update a person" $ do ...
  it "should delete a person" $ do ...
  it "should not find deleted person" $ do ...
```
(`DAL/IntegrationSpec.hs`)

---

*Testing analysis: 2026-05-24*
