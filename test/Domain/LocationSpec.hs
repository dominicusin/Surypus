{-# LANGUAGE OverloadedStrings #-}
-- | Domain Location Tests
module Domain.LocationSpec where

import Test.Hspec
import Domain.Location

spec :: Spec
spec = do
  describe "Location" $ do
    it "creates location with required fields" $ do
      let l = Location
            { locationId = Nothing
            , locationName = "Main Warehouse"
            , locationType = 1
            , locationFlags = 0
            , locationParentId = Nothing
            , locationAddress = Just "Moscow, Lenina 1"
            , locationPhone = Just "+79001234567"
            , locationEmail = Just "warehouse@company.com"
            , locationCoordX = Just 55.7558
            , locationCoordY = Just 37.6173
            , locationMainOrgId = Nothing
            }
      locationName l `shouldBe` "Main Warehouse"
      locationType l `shouldBe` 1

    it "supports location types" $ do
      let w = Location Nothing "Warehouse" 0 0 Nothing Nothing Nothing Nothing Nothing Nothing Nothing
      let a = Location Nothing "Address" 1 0 Nothing Nothing Nothing Nothing Nothing Nothing Nothing
      locationType w `shouldBe` 0
      locationType a `shouldBe` 1

  describe "LocationFilter" $ do
    it "has default pagination" $ do
      let f = LocationFilter Nothing Nothing 100 0
      lfLimit f `shouldBe` 100
      lfOffset f `shouldBe` 0

    it "supports name filter" $ do
      let f = LocationFilter (Just "Main") Nothing 50 0
      lfName f `shouldBe` Just "Main"
