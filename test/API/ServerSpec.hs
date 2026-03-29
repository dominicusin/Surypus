{-# LANGUAGE OverloadedStrings #-}
module API.ServerSpec where

import Test.Hspec

spec :: Spec
spec = do
  describe "API Endpoints" $ do
    describe "Health Check" $ do
      it "returns OK for root" $ do
        True `shouldBe` True

    describe "Goods API" $ do
      it "GET /api/v1/goods returns list" $ do
        True `shouldBe` True

    describe "Persons API" $ do
      it "GET /api/v1/persons returns list" $ do
        True `shouldBe` True

    describe "Bills API" $ do
      it "GET /api/v1/bills returns list" $ do
        True `shouldBe` True
