{-# LANGUAGE OverloadedStrings #-}

-- | Tests for DAL.DB module
module DAL.DBSpec (spec) where

import Test.Hspec
import Data.IORef (newIORef, readIORef)
import Data.Text (Text)
import qualified Data.Text as T

import DAL.DB

spec :: Spec
spec = do
  describe "DAL.DB - In-Memory Database" $ do

    describe "Person Operations" $ do
      it "should create a new database" $ do
        db <- newDatabase
        persons <- queryPersons db 10 0
        length persons `shouldBe` 3  -- testPersons has 3 records

      it "should find person by ID" $ do
        db <- newDatabase
        result <- findPersonById db 1
        case result of
          Just p -> pName p `shouldBe` T.pack "Company A"
          Nothing -> fail "Should find person with ID 1"

      it "should query persons with pagination" $ do
        db <- newDatabase
        page1 <- queryPersons db 2 0
        page2 <- queryPersons db 2 2
        length page1 `shouldBe` 2
        length page2 `shouldBe` 1  -- 3 total, page 2 (offset 2) has 1

      it "should query persons by status" $ do
        db <- newDatabase
        result <- queryPersonsByStatus db 0
        length result `shouldBe` 3  -- All test persons have status 0

      it "should insert new person" $ do
        db <- newDatabase
        let newPerson = PersonStub
              { pId = 999
              , pCode = Just "P999"
              , pName = T.pack "New Company"
              , pINN = Just "9999999999"
              , pKPP = Just "999999999"
              , pPersonType = 1
              , pStatus = 1
              }
        pid <- insertPerson db newPerson
        pid `shouldBe` 999
        found <- findPersonById db 999
        case found of
          Just p -> pName p `shouldBe` T.pack "New Company"
          Nothing -> fail "Should find inserted person"

      it "should update person" $ do
        db <- newDatabase
        found <- findPersonById db 1
        case found of
          Just person -> do
            let updated = person { pName = T.pack "Updated Name" }
            updatePerson db 1 updated
            result <- findPersonById db 1
            case result of
              Just p -> pName p `shouldBe` T.pack "Updated Name"
              Nothing -> fail "Should find updated person"
          Nothing -> fail "Should find person to update"

      it "should delete person" $ do
        db <- newDatabase
        _ <- insertPerson db (PersonStub 999 (Just "P999") (T.pack "Temp") Nothing Nothing 1 0)
        found1 <- findPersonById db 999
        case found1 of
          Just _ -> do
            deletePerson db 999
            found2 <- findPersonById db 999
            found2 `shouldBe` Nothing
          Nothing -> fail "Should insert before delete"

    describe "Goods Operations" $ do
      it "should find goods by ID" $ do
        db <- newDatabase
        result <- findGoodsById db 1
        case result of
          Just g -> gName g `shouldBe` T.pack "Product A"
          Nothing -> fail "Should find goods with ID 1"

      it "should query goods with pagination" $ do
        db <- newDatabase
        page1 <- queryGoods db 2 0
        page2 <- queryGoods db 2 2
        length page1 `shouldBe` 2
        length page2 `shouldBe` 1

      it "should insert goods" $ do
        db <- newDatabase
        let newGoods = GoodsStub
              { gId = 999
              , gCode = Just "G999"
              , gName = T.pack "New Product"
              , gBarcode = Nothing
              , gUnitId = 1
              , gParentId = Nothing
              }
        gid <- insertGoods db newGoods
        gid `shouldBe` 999

      it "should update goods" $ do
        db <- newDatabase
        found <- findGoodsById db 1
        case found of
          Just goods -> do
            let updated = goods { gName = T.pack "Updated Product" }
            updateGoods db 1 updated
            result <- findGoodsById db 1
            case result of
              Just g -> gName g `shouldBe` T.pack "Updated Product"
              Nothing -> fail "Should find updated goods"
          Nothing -> fail "Should find goods to update"

    describe "Location Operations" $ do
      it "should find location by ID" $ do
        db <- newDatabase
        result <- findLocationById db 1
        case result of
          Just l -> lName l `shouldBe` T.pack "Main Warehouse"
          Nothing -> fail "Should find location with ID 1"

      it "should query locations by type" $ do
        db <- newDatabase
        warehouses <- queryLocationsByType db 1
        length warehouses `shouldBe` 2  -- 2 warehouses in test data

        shops <- queryLocationsByType db 2
        length shops `shouldBe` 1  -- 1 shop in test data

      it "should insert location" $ do
        db <- newDatabase
        let newLoc = LocationStub
              { lId = 999
              , lCode = Just "LOC999"
              , lName = T.pack "New Location"
              , lType = 3
              }
        lid <- insertLocation db newLoc
        lid `shouldBe` 999

    describe "Stock Operations" $ do
      it "should find stock by ID" $ do
        db <- newDatabase
        result <- findStockById db 1
        case result of
          Just s -> sQtty s `shouldBe` 100
          Nothing -> fail "Should find stock with ID 1"

      it "should query stock by goods ID" $ do
        db <- newDatabase
        result <- queryStockByGoods db 1
        length result `shouldBe` 2  -- Product 1 in 2 locations

      it "should query stock by location ID" $ do
        db <- newDatabase
        result <- queryStockByLocation db 1
        length result `shouldBe` 2  -- Location 1 has 2 items

      it "should query stock by goods and location" $ do
        db <- newDatabase
        result <- queryStockByGoodsAndLocation db 1 1
        length result `shouldBe` 1

      it "should insert stock" $ do
        db <- newDatabase
        let newStock = StockStub
              { sId = 999
              , sGoodsId = 1
              , sLocationId = 1
              , sQtty = 50
              , sResrvQtty = 0
              }
        sid <- insertStock db newStock
        sid `shouldBe` 999

      it "should update stock quantity" $ do
        db <- newDatabase
        found <- findStockById db 1
        case found of
          Just stock -> do
            let updated = stock { sQtty = 150 }
            updateStock db 1 updated
            result <- findStockById db 1
            case result of
              Just s -> sQtty s `shouldBe` 150
              Nothing -> fail "Should find updated stock"
          Nothing -> fail "Should find stock to update"

    describe "Bill Operations" $ do
      it "should insert bill" $ do
        db <- newDatabase
        let newBill = BillStub
              { billId = 999
              , billTotal = 5000.0
              }
        bid <- insertBill db newBill
        bid `shouldBe` 999

      it "should find bill by ID" $ do
        db <- newDatabase
        let newBill = BillStub 999 5000.0 "USD" 1.0
        _ <- insertBill db newBill
        result <- findBillById db 999
        case result of
          Just b -> billTotal b `shouldBe` 5000.0
          Nothing -> fail "Should find inserted bill"

      it "should query bills with pagination" $ do
        db <- newDatabase
        testBills <- queryBills db 10 0
        length testBills `shouldBe` 1  -- Test data has 1 bill
