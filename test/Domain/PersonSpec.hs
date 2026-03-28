{-# LANGUAGE OverloadedStrings #-}
module Domain.PersonSpec where

import Test.Hspec
import Domain.Person

spec :: Spec
spec = do
  describe "Person" $ do
    it "creates person with required fields" $ do
      let p = Person
            { personId = Nothing
            , personCode = Just "001"
            , personName = "Test Company"
            , personINN = Just "1234567890"
            , personKPP = Nothing
            , personKind = 1
            , personStatus = 0
            , personPhone = Nothing
            , personEmail = Nothing
            , personAddress = Nothing
            , personCredit = 0
            , personDiscount = 0
            }
      personName p `shouldBe` "Test Company"
