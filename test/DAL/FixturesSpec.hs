{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

-- | Tests for DAL.Fixtures module
module DAL.FixturesSpec (spec) where

import Test.Hspec
import Test.Hspec.QuickCheck
import Test.QuickCheck

import DAL.Fixtures
import qualified DAL.DB as DB

spec :: Spec
spec = do
  describe "DAL.Fixtures - Test Fixtures" $ do

    describe "Person Fixtures" $ do
      it "should create minimal person with valid ID" $ do
        let p = minimalPerson 1
        DB.pId p `shouldBe` 1
        isValidPerson p `shouldBe` True

      it "should create full person with custom data" $ do
        let p = fullPerson 999 "CUSTOM" "Custom Person" 2 1
        DB.pId p `shouldBe` 999
        DB.pName p `shouldBe` "Custom Person"
        DB.pPersonType p `shouldBe` 2
        isValidPerson p `shouldBe` True

      prop "arbitrary persons are always valid" $ \(n :: Int) ->
        let p = minimalPerson (fromIntegral (abs n `mod` 100 + 1))
        in isValidPerson p

    describe "Goods Fixtures" $ do
      it "should create minimal goods with valid ID" $ do
        let g = minimalGoods 1
        DB.gId g `shouldBe` 1
        isValidGoods g `shouldBe` True

      it "should create full goods with custom data" $ do
        let g = fullGoods 999 "FULLCODE" "Full Goods" 5
        DB.gId g `shouldBe` 999
        DB.gName g `shouldBe` "Full Goods"
        DB.gUnitId g `shouldBe` 5
        isValidGoods g `shouldBe` True

      prop "arbitrary goods are always valid" $ \(n :: Int) ->
        let g = minimalGoods (fromIntegral (abs n `mod` 10000 + 1))
        in isValidGoods g

    describe "Location Fixtures" $ do
      it "should create minimal location" $ do
        let l = minimalLocation 1
        DB.lId l `shouldBe` 1
        isValidLocation l `shouldBe` True

      it "should create warehouse location" $ do
        let l = warehouseLocation 10 "Main WH"
        DB.lId l `shouldBe` 10
        DB.lType l `shouldBe` 1
        isValidLocation l `shouldBe` True

      it "should create shop location" $ do
        let l = shopLocation 20 "Shop 1"
        DB.lId l `shouldBe` 20
        DB.lType l `shouldBe` 2
        isValidLocation l `shouldBe` True

      prop "arbitrary locations are valid" $ \(n :: Int) ->
        let l = minimalLocation (fromIntegral (abs n `mod` 1000 + 1))
        in isValidLocation l

    describe "Stock Fixtures" $ do
      it "should create minimal stock" $ do
        let s = minimalStock 1 1 1
        DB.sId s `shouldBe` 1
        DB.sQtty s `shouldBe` 100
        isValidStock s `shouldBe` True

      it "should create stock with specific quantities" $ do
        let s = stockWithQty 1 1 1 500 50
        DB.sQtty s `shouldBe` 500
        DB.sResrvQtty s `shouldBe` 50
        isValidStock s `shouldBe` True

      it "should validate stock constraints" $ do
        let validStock = stockWithQty 1 1 1 100 50
        isValidStock validStock `shouldBe` True

        -- Invalid: reserved > available
        let invalidStock = stockWithQty 1 1 1 100 150
        isValidStock invalidStock `shouldBe` False

      prop "arbitrary stock respects constraints" $ \(Positive qty) (Positive resrv) ->
        let s = minimalStock 1 1 1
            s' = s { DB.sQtty = min qty 10000, DB.sResrvQtty = min resrv (min qty 10000) }
        in isValidStock s'

    describe "Bill Fixtures" $ do
      it "should create minimal bill" $ do
        let b = minimalBill 1
        DB.billId b `shouldBe` 1
        DB.billTotal b `shouldBe` 1000.0

      it "should create bill with custom amount" $ do
        let b = billWithAmount 999 5500.0
        DB.billId b `shouldBe` 999
        DB.billTotal b `shouldBe` 5500.0

    describe "Scenario Fixtures" $ do
      it "should create inventory scenario" $ do
        db <- createInventoryScenario
        stock <- DB.queryStock db 100 0
        length stock `shouldBe` 6  -- 3 initial + 3 added

      it "should seed database with test data" $ do
        db <- seedDatabase

        -- Check persons
        persons <- DB.queryPersons db 100 0
        length persons `shouldBe` 6  -- 3 initial + 3 added

        -- Check goods
        goods <- DB.queryGoods db 100 0
        length goods `shouldBe` 6  -- 3 initial + 3 added

        -- Check locations
        locations <- DB.queryLocations db 100 0
        length locations `shouldBe` 5  -- 3 initial + 2 added

        -- Check stock
        stock <- DB.queryStock db 100 0
        length stock `shouldBe` 6  -- 3 initial + 3 added

    describe "Validation Helpers" $ do
      it "should validate persons correctly" $ do
        let validPerson = minimalPerson 1
        isValidPerson validPerson `shouldBe` True

        let invalidPerson = minimalPerson (-1)
        isValidPerson invalidPerson `shouldBe` False

      it "should validate goods correctly" $ do
        let validGoods = minimalGoods 1
        isValidGoods validGoods `shouldBe` True

        let invalidGoods = minimalGoods (-1)
        isValidGoods invalidGoods `shouldBe` False

      it "should validate stock correctly" $ do
        let validStock = minimalStock 1 1 1
        isValidStock validStock `shouldBe` True

        let invalidStock = stockWithQty 1 1 1 100 200  -- reserved > qty
        isValidStock invalidStock `shouldBe` False

      it "should validate locations correctly" $ do
        let validLocation = minimalLocation 1
        isValidLocation validLocation `shouldBe` True

        let invalidLocation = minimalLocation (-1)
        isValidLocation invalidLocation `shouldBe` False
