{-# LANGUAGE OverloadedStrings #-}
-- | Domain Person Tests
module Domain.PersonSpec where

import Test.Hspec
import Domain.Person

spec :: Spec
spec = do
  describe "Person" $ do
    it "creates person with required fields" $ do
      let p = Person
            { personId = Nothing
            , personName = "Test Company"
            , personFlags = 0
            , personStatus = 0
            }
      personName p `shouldBe` "Test Company"

    it "supports status values" $ do
      let p1 = Person Nothing "Active" 0 0
      let p2 = Person Nothing "Disabled" 0 1
      personStatus p1 `shouldBe` 0
      personStatus p2 `shouldBe` 1

  describe "PersonFilter" $ do
    it "has default pagination" $ do
      let f = PersonFilter Nothing Nothing Nothing 100 0
      pfLimit f `shouldBe` 100
      pfOffset f `shouldBe` 0

  describe "PersonExtended" $ do
    it "creates extended person" $ do
      let pe = PersonExtended
            { peId = 1
            , peName = "Company"
            , peFlags = 0
            , peStatus = 0
            , peInn = Just "1234567890"
            , peKpp = Just "123456789"
            , pePhone = Just "+79001234567"
            , peEmail = Just "test@company.com"
            , peAddress = Just "Moscow"
            }
      peInn pe `shouldBe` Just "1234567890"
