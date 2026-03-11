{-# LANGUAGE OverloadedStrings #-}
-- | Main test entry point
module Main where

import Test.Hspec
import Test.QuickCheck
import Data.Time (fromGregorian)

import Domain.Types
import Domain.TypesSpec
import Domain.Goods
import Domain.GoodsSpec
import Domain.Person
import Domain.PersonSpec
import Domain.Bill
import Domain.BillSpec
import Domain.Location
import Domain.LocationSpec
import Domain.PayrollSpec
import API.ServerSpec
import DB.RepositoriesSpec

main :: IO ()
main = hspec $ do
  describe "Domain.Types" $ do
    it "PPID conversion works correctly" $ do
      unPPID (PPID 42) `shouldBe` 42
      ppidToInt64 (PPID 100) `shouldBe` 100
      int64ToPPID 200 `shouldBe` PPID 200

    it "Money operations work" $ do
      Money 10 + Money 5 `shouldBe` Money 15
      Money 100 * Money 2 `shouldBe` Money 200
      mempty `shouldBe` Money 0

    it "Flags32 operations work" $ do
      Flags32 1 <> Flags32 2 `shouldBe` Flags32 3
      hasFlag (Flags32 5) (Flags32 1) `shouldBe` True
      hasFlag (Flags32 4) (Flags32 1) `shouldBe` False

    it "Pagination calculations work" $ do
      offset (Pagination 0 50) `shouldBe` 0
      offset (Pagination 1 50) `shouldBe` 50
      offset (Pagination 2 25) `shouldBe` 50
      limit (Pagination 0 100) `shouldBe` 100

  describe "Domain.Goods" $ do
    it "creates valid goods" $ do
      let g = Goods Nothing "Test Goods" Nothing 0 0 Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing
      goodsName g `shouldBe` "Test Goods"
      goodsKind g `shouldBe` 0

    it "goods filter defaults" $ do
      let f = GoodsFilter Nothing Nothing Nothing Nothing 100 0
      gfLimit f `shouldBe` 100
      gfOffset f `shouldBe` 0

  describe "Domain.Person" $ do
    it "creates valid person" $ do
      let p = Person Nothing "Test Company" 0 0
      personName p `shouldBe` "Test Company"
      personStatus p `shouldBe` 0

  describe "Domain.Bill" $ do
    it "creates valid bill" $ do
      let b = Bill Nothing "0001" (fromGregorian 2024 1 1) 1 Nothing Nothing 1 1000 1 1 0 Nothing Nothing Nothing Nothing Nothing Nothing
      billCode b `shouldBe` "0001"
      billAmount b `shouldBe` 1000

  describe "Domain.Location" $ do
    it "creates valid location" $ do
      let l = Location Nothing "Main Warehouse" 1 0 Nothing Nothing Nothing Nothing Nothing Nothing Nothing
      locationName l `shouldBe` "Main Warehouse"
      locationType l `shouldBe` 1

  describe "Domain.Payroll" PayrollSpec.spec

  describe "API.Server" serverSpec

  describe "DB.Repositories" dbRepositoriesSpec
