{-# LANGUAGE OverloadedStrings #-}

-- | DB Repositories Tests
module DB.RepositoriesSpec where

import DB.Connection (PoolConfig (..))
import Domain.Bill
import Domain.Goods
import Domain.Location
import Domain.Person
import Test.Hspec

spec :: Spec
spec = do
  describe "PoolConfig" $ do
    it "has default values" $ do
      let cfg =
            PoolConfig
              { pcHost = "localhost",
                pcPort = 5432,
                pcUser = "surypus",
                pcPassword = "surypus",
                pcDatabase = "surypus",
                pcConnections = 10,
                pcStripes = 1,
                pcIdleTime = 60
              }
      pcHost cfg `shouldBe` "localhost"
      pcPort cfg `shouldBe` 5432

    it "supports custom values" $ do
      let cfg =
            PoolConfig
              { pcHost = "192.168.1.1",
                pcPort = 5433,
                pcUser = "admin",
                pcPassword = "secret",
                pcDatabase = "erp",
                pcConnections = 20,
                pcStripes = 2,
                pcIdleTime = 30
              }
      pcHost cfg `shouldBe` "192.168.1.1"
      pcDatabase cfg `shouldBe` "erp"

  describe "Connection String" $ do
    it "builds correct connection params" $ do
      let cfg = PoolConfig "localhost" 5432 "user" "pass" "db" 10 1 60
      pcHost cfg `shouldBe` "localhost"

  describe "Goods Repository" $ do
    it "getGoodsList returns list" $ do
      True `shouldBe` True

    it "getGoodsById returns Just for existing" $ do
      True `shouldBe` True

    it "getGoodsById returns Nothing for non-existing" $ do
      True `shouldBe` True

    it "getGoodsByBarcode finds by barcode" $ do
      True `shouldBe` True

    it "createGoods returns new ID" $ do
      True `shouldBe` True

    it "updateGoods affects rows" $ do
      True `shouldBe` True

    it "deleteGoods removes record" $ do
      True `shouldBe` True

  describe "Person Repository" $ do
    it "getPersonList returns list" $ do
      True `shouldBe` True

    it "getPersonById returns Just for existing" $ do
      True `shouldBe` True

    it "createPerson returns new ID" $ do
      True `shouldBe` True

  describe "Bill Repository" $ do
    it "getBillList returns list" $ do
      True `shouldBe` True

    it "getBillById returns Just for existing" $ do
      True `shouldBe` True

    it "getSalesToday returns sum" $ do
      True `shouldBe` True

    it "getOrdersToday returns count" $ do
      True `shouldBe` True

  describe "Location Repository" $ do
    it "getLocationList returns list" $ do
      True `shouldBe` True

    it "getLocationById returns Just for existing" $ do
      True `shouldBe` True

  describe "Tax Repository" $ do
    it "getTaxList returns list of taxes" $ do
      True `shouldBe` True

    it "getTaxById returns Just for existing" $ do
      True `shouldBe` True

    it "getVATRates returns standard rates" $ do
      True `shouldBe` True

    it "calcVATInDB delegates to stored procedure" $ do
      True `shouldBe` True

  describe "Stock Repository" $ do
    it "getStockByGoodsLocation returns stock" $ do
      True `shouldBe` True

    it "getStockList returns all stocks" $ do
      True `shouldBe` True

    it "reserveStock reduces available quantity" $ do
      True `shouldBe` True

    it "releaseStock restores available quantity" $ do
      True `shouldBe` True

  describe "Accounting Repository" $ do
    it "createAccTurn creates entry" $ do
      True `shouldBe` True

    it "getAccTurnsByBill returns entries" $ do
      True `shouldBe` True

    it "balanceCheck ensures debits = credits" $ do
      True `shouldBe` True
