{-# LANGUAGE OverloadedStrings #-}
-- | Domain Types Tests
module Domain.TypesSpec where

import Test.Hspec
import Test.QuickCheck
import Domain.Types
import Data.Int (Int64)

spec :: Spec
spec = do
  describe "PPID" $ do
    it "wraps Int64 correctly" $ do
      unPPID (PPID 123) `shouldBe` 123

    it "converts to/from Int64" $ do
      ppidToInt64 (int64ToPPID 456) `shouldBe` 456

    it "supports Eq" $ do
      PPID 1 == PPID 1 `shouldBe` True
      PPID 1 == PPID 2 `shouldBe` False

    it "supports Ord" $ do
      PPID 1 < PPID 2 `shouldBe` True
      PPID 10 > PPID 5 `shouldBe` True

  describe "Money" $ do
    it "supports addition" $ do
      Money 10 + Money 5 `shouldBe` Money 15

    it "supports subtraction" $ do
      Money 10 - Money 3 `shouldBe` Money 7

    it "supports multiplication" $ do
      Money 10 * Money 2 `shouldBe` Money 20

    it "has zero identity" $ do
      Money 0 + Money 5 `shouldBe` Money 5
      Money 5 + Money 0 `shouldBe` Money 5

    it "converts from Double" $ do
      fromMoney (toMoney 100.5) `shouldBe` 101

  describe "Flags32" $ do
    it "supports OR operation" $ do
      Flags32 1 <> Flags32 2 `shouldBe` Flags32 3

    it "supports AND check" $ do
      hasFlag (Flags32 5) (Flags32 1) `shouldBe` True
      hasFlag (Flags32 5) (Flags32 2) `shouldBe` True
      hasFlag (Flags32 4) (Flags32 1) `shouldBe` False

    it "has empty identity" $ do
      mempty <> Flags32 5 `shouldBe` Flags32 5

  describe "Pagination" $ do
    it "calculates offset correctly" $ do
      offset (Pagination 0 50) `shouldBe` 0
      offset (Pagination 1 50) `shouldBe` 50
      offset (Pagination 2 25) `shouldBe` 50

    it "returns page size" $ do
      limit (Pagination 0 100) `shouldBe` 100

    it "has defaults" $ do
      defaultPagination `shouldBe` Pagination 0 50
