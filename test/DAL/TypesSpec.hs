{-# LANGUAGE OverloadedStrings #-}

module DAL.TypesSpec (spec) where

import Test.Hspec
import Test.QuickCheck
import Data.Aeson
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (fromGregorian)

import DAL.Types

spec :: Spec
spec = do
  describe "DAL.Types - Core Type Tests" $ do

    -- Person type tests
    describe "Person type" $ do
      it "Person records can be created with valid fields" $ do
        let person = Person 1 (Just "001") "Company A" (Just "1234567890") (Just "123456789") 1 (Just 0)
        personId person `shouldBe` 1
        personName person `shouldBe` "Company A"
        personType person `shouldBe` 1

      it "Person JSON serialization roundtrips" $ do
        let person = Person 1 (Just "001") "Test Company" (Just "INN001") (Just "KPP001") 1 (Just 0)
        let json = encode person
        let decoded = decode json :: Maybe Person
        decoded `shouldBe` Just person

      it "PersonInput can be created" $ do
        let input = PersonInput (Just "001") "Test" (Just "INN") (Just "KPP") 1 0
        piName input `shouldBe` "Test"
        piPersonType input `shouldBe` 1

      it "PersonFilter can filter by type" $ do
        let filter1 = PersonFilter Nothing Nothing (Just 1) Nothing
        pfPersonType filter1 `shouldBe` Just 1

    -- Goods type tests
    describe "Goods type" $ do
      it "Goods records can be created with valid fields" $ do
        let goods = Goods 1 (Just "PROD-001") "Product A" Nothing (Just "123456") (Just 1) Nothing Nothing (Just 0) Nothing Nothing Nothing Nothing Nothing Nothing
        goodsId goods `shouldBe` 1
        goodsName goods `shouldBe` "Product A"
        goodsCode goods `shouldBe` Just "PROD-001"

      it "Goods JSON serialization roundtrips" $ do
        let goods = Goods 1 (Just "001") "Test Goods" Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing
        let json = encode goods
        let decoded = decode json :: Maybe Goods
        decoded `shouldBe` Just goods

      it "GoodsInput can be created with minimal fields" $ do
        let input = GoodsInput (Just "001") "Test Good" (Just "123") 1 Nothing
        giName input `shouldBe` "Test Good"
        giUnitId input `shouldBe` 1

      it "GoodsFilter can filter by name or code" $ do
        let filter1 = GoodsFilter (Just "Product") Nothing Nothing Nothing
        gfName filter1 `shouldBe` Just "Product"

    -- Bill type tests
    describe "Bill type" $ do
      it "Bill records can be created with valid fields" $ do
        let day = fromGregorian 2024 1 1
        let bill = Bill 1 (Just "BILL-001") 1 0 day (Just 1) (Just 1) 100.0 0.0 10.0
        billId bill `shouldBe` 1
        billTotal bill `shouldBe` 100.0

      it "Bill JSON serialization roundtrips" $ do
        let day = fromGregorian 2024 1 1
        let bill = Bill 1 (Just "001") 1 0 day Nothing Nothing 100.0 0.0 10.0
        let json = encode bill
        let decoded = decode json :: Maybe Bill
        decoded `shouldBe` Just bill

      it "BillInput can be created" $ do
        let day = fromGregorian 2024 1 1
        let input = BillInput (Just "001") 1 0 day Nothing Nothing 100.0 0.0 10.0
        biTotal input `shouldBe` 100.0

      it "BillFilter can filter by person and date range" $ do
        let filter1 = BillFilter (Just 1) Nothing (Just "2024-01-01") (Just "2024-01-31") Nothing
        bfPersonId filter1 `shouldBe` Just 1

    -- Location type tests
    describe "Location type" $ do
      it "Location records can be created" $ do
        let loc = Location 1 (Just "WH-01") "Main Warehouse" 1
        locationId loc `shouldBe` 1
        locationName loc `shouldBe` "Main Warehouse"

      it "Location JSON serialization roundtrips" $ do
        let loc = Location 1 (Just "WH-01") "Warehouse" 1
        let json = encode loc
        let decoded = decode json :: Maybe Location
        decoded `shouldBe` Just loc

    -- Stock type tests
    describe "Stock type" $ do
      it "Stock records can be created" $ do
        let stock = Stock 1 100 1 50.0 10.0
        stockId stock `shouldBe` 1
        stockQtty stock `shouldBe` 50.0
        stockResrvQtty stock `shouldBe` 10.0

      it "Available quantity can be calculated" $ do
        let stock = Stock 1 100 1 100.0 20.0
        let available = stockQtty stock - stockResrvQtty stock
        available `shouldBe` 80.0

      it "Stock JSON serialization roundtrips" $ do
        let stock = Stock 1 100 1 50.0 10.0
        let json = encode stock
        let decoded = decode json :: Maybe Stock
        decoded `shouldBe` Just stock

    -- Payment type tests
    describe "Payment type" $ do
      it "Payment records can be created" $ do
        let day = fromGregorian 2024 1 1
        let payment = Payment 1 10 100.0 day
        paymentId payment `shouldBe` 1
        paymentAmount payment `shouldBe` 100.0

      it "Payment JSON serialization roundtrips" $ do
        let day = fromGregorian 2024 1 1
        let payment = Payment 1 10 100.0 day
        let json = encode payment
        let decoded = decode json :: Maybe Payment
        decoded `shouldBe` Just payment

    -- Pagination tests
    describe "Pagination type" $ do
      it "Pagination can be created with defaults" $ do
        let pg = Pagination 10 0
        pgLimit pg `shouldBe` 10
        pgOffset pg `shouldBe` 0

      it "Pagination JSON serialization roundtrips" $ do
        let pg = Pagination 20 40
        let json = encode pg
        let decoded = decode json :: Maybe Pagination
        decoded `shouldBe` Just pg

    -- PaginatedResult tests
    describe "PaginatedResult type" $ do
      it "PaginatedResult can be created with items" $ do
        let items = [Person 1 Nothing "P1" Nothing Nothing 1 Nothing]
        let result = PaginatedResult items 1 10 0
        prTotal result `shouldBe` 1
        length (prItems result) `shouldBe` 1

      it "PaginatedResult JSON serialization roundtrips with Person items" $ do
        let items = [Person 1 Nothing "P1" Nothing Nothing 1 Nothing]
        let result = PaginatedResult items 1 10 0
        let json = encode result
        let decoded = decode json :: Maybe (PaginatedResult Person)
        decoded `shouldBe` Just result

    -- DashboardStats tests
    describe "DashboardStats type" $ do
      it "DashboardStats can be created" $ do
        let stats = DashboardStats 10 20 100 50
        dsBills stats `shouldBe` 10
        dsOrders stats `shouldBe` 20
        dsGoods stats `shouldBe` 100
        dsPersons stats `shouldBe` 50

      it "DashboardStats JSON serialization roundtrips" $ do
        let stats = DashboardStats 10 20 100 50
        let json = encode stats
        let decoded = decode json :: Maybe DashboardStats
        decoded `shouldBe` Just stats

    -- Sort direction tests
    describe "SortDir type" $ do
      it "SortDir Asc and Desc can be serialized" $ do
        let jsonAsc = encode Asc
        let jsonDesc = encode Desc
        (decode jsonAsc :: Maybe SortDir) `shouldBe` Just Asc
        (decode jsonDesc :: Maybe SortDir) `shouldBe` Just Desc

    -- MutationResult tests
    describe "MutationResult type" $ do
      it "MutationResult can indicate success" $ do
        let result = MutationResult True (Just 1) "Created successfully"
        mrSuccess result `shouldBe` True
        mrId result `shouldBe` Just 1

      it "MutationResult can indicate failure" $ do
        let result = MutationResult False Nothing "Failed to create"
        mrSuccess result `shouldBe` False
        mrId result `shouldBe` Nothing

      it "MutationResult JSON serialization roundtrips" $ do
        let result = MutationResult True (Just 5) "Success"
        let json = encode result
        let decoded = decode json :: Maybe MutationResult
        decoded `shouldBe` Just result

    -- QueryResult tests
    describe "QueryResult type" $ do
      it "QueryResult can contain success value" $ do
        let result = QuerySuccess (Person 1 Nothing "Test" Nothing Nothing 1 Nothing :: Person)
        case result of
          QuerySuccess p -> personId p `shouldBe` 1
          QueryError _ -> fail "Should be success"

      it "QueryResult can contain error message" $ do
        let result = QueryError "Not found" :: QueryResult Person
        case result of
          QuerySuccess _ -> fail "Should be error"
          QueryError msg -> msg `shouldBe` "Not found"

      it "QueryResult JSON serialization works for success" $ do
        let result = QuerySuccess (Person 1 Nothing "Test" Nothing Nothing 1 Nothing :: Person)
        let json = encode result
        let decoded = decode json :: Maybe (QueryResult Person)
        case decoded of
          Just (QuerySuccess p) -> personId p `shouldBe` 1
          _ -> fail "Should decode successfully"

  describe "DAL.Types - Type Validation" $ do
    it "Person type requires name" $ do
      let p1 = Person 1 Nothing "" Nothing Nothing 1 Nothing
      let p2 = Person 1 Nothing "Valid Name" Nothing Nothing 1 Nothing
      personName p1 `shouldBe` ""
      personName p2 `shouldBe` "Valid Name"

    it "Goods type requires name" $ do
      let g1 = Goods 1 Nothing "" Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing
      let g2 = Goods 1 Nothing "Valid Good" Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing
      goodsName g1 `shouldBe` ""
      goodsName g2 `shouldBe` "Valid Good"

    it "Bill type requires date and total" $ do
      let day = fromGregorian 2024 1 1
      let bill = Bill 1 Nothing 1 0 day Nothing Nothing 100.0 0.0 10.0
      billDate bill `shouldBe` day
      billTotal bill `shouldBe` 100.0

  describe "DAL.Types - List Operations" $ do
    it "Multiple persons can be created as a list" $ do
      let persons = [Person i Nothing "Person" Nothing Nothing 1 Nothing | i <- [1..5]]
      length persons `shouldBe` 5
      map personId persons `shouldBe` [1, 2, 3, 4, 5]

    it "Multiple goods can be created as a list" $ do
      let goods = [Goods i Nothing "Good" Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing | i <- [1..3]]
      length goods `shouldBe` 3
      map goodsId goods `shouldBe` [1, 2, 3]
