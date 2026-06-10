-- | Main test suite for Surypus
{-# LANGUAGE OverloadedStrings #-}

module Main where

import Test.Hspec
import Test.QuickCheck
import qualified Data.Aeson as A
import Data.Time.Calendar (fromGregorian)
import qualified Finance.TaxSpec
import qualified Finance.AccountingSpec
import DAL.Types

main :: IO ()
main = hspec $ do
  Finance.TaxSpec.spec
  Finance.AccountingSpec.spec

  describe "DAL.Types JSON roundtrip" $ do
    it "Goods roundtrip" $ do
      let g = Goods 1 (Just "001") "Test" Nothing (Just "123456") (Just 1) Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing Nothing
      A.decode (A.encode g) `shouldBe` Just g

    it "Person roundtrip" $ do
      let p = Person 1 (Just "001") "Test" (Just "7707083893") (Just "770701001") 1 (Just 1)
      A.decode (A.encode p) `shouldBe` Just p

    it "Bill roundtrip" $ do
      let b = Bill 1 (Just "B-001") 1 0 (fromGregorian 2024 1 1) (Just 1) (Just 1) 1000.0 0.0 200.0
      A.decode (A.encode b) `shouldBe` Just b

    it "User roundtrip" $ do
      let u = User 1 "admin" (Just "hash") (Just "admin@test.ru") (Just 1) 1 1
      A.decode (A.encode u) `shouldBe` Just u

    it "MutationResult roundtrip" $ do
      let mr = MutationResult True (Just 42) "created"
      A.decode (A.encode mr) `shouldBe` Just mr

    it "Location roundtrip" $ do
      let l = Location 1 (Just "MSK") "Main" 1
      A.decode (A.encode l) `shouldBe` Just l

    it "Employee roundtrip" $ do
      let e = Employee 1 "Ivanov" "001" (Just "123") (Just (fromGregorian 2020 1 1)) 1
      A.decode (A.encode e) `shouldBe` Just e

    it "Salary roundtrip" $ do
      let s = Salary 1 1 (fromGregorian 2024 1 1) 100000 87000 13000 0 0
      A.decode (A.encode s) `shouldBe` Just s

    it "EmployeeInput roundtrip" $ do
      let ei = EmployeeInput "Ivanov" "001" (Just "123") (Just (fromGregorian 2020 1 1)) 1
      A.decode (A.encode ei) `shouldBe` Just ei

    it "SalaryInput roundtrip" $ do
      let si = SalaryInput 1 (fromGregorian 2024 1 1) 100000 13000 0 0
      A.decode (A.encode si) `shouldBe` Just si

  describe "QueryResult" $ do
    it "QuerySuccess wraps value" $ do
      let q = QuerySuccess (42 :: Int)
      q `shouldBe` QuerySuccess 42

    it "QueryError wraps message" $ do
      let q = QueryError "Not Found" :: QueryResult Int
      q `shouldBe` QueryError "Not Found"

    it "QuerySuccess ToJSON roundtrip" $ do
      let q = QuerySuccess (MutationResult True (Just 1) "ok")
      A.decode (A.encode q) `shouldBe` Just q

  describe "MutationResult" $ do
    it "fields are accessible" $ do
      let mr = MutationResult True (Just 5) "success"
      mrSuccess mr `shouldBe` True
      mrId mr `shouldBe` Just 5
      mrMessage mr `shouldBe` "success"
