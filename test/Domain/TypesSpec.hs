{-# LANGUAGE OverloadedStrings #-}
-- | Domain Types Tests
module Domain.TypesSpec where

import Test.Hspec

typesSpec :: Spec
typesSpec = do
  describe "Domain Types" $ do
    it "placeholder test passes" $ do
      True `shouldBe` True
