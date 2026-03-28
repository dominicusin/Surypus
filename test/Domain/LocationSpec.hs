{-# LANGUAGE OverloadedStrings #-}
module Domain.LocationSpec where

import Test.Hspec
import Domain.Location

spec :: Spec
spec = do
  describe "Location" $ do
    it "creates location with required fields" $ do
      let l = Location
            { locationId = Nothing
            , locationCode = Nothing
            , locationName = "Main Warehouse"
            , locationType = 1
            , locationAddress = Nothing
            , locationStatus = 0
            , locationCapacity = Nothing
            , locationParent = Nothing
            }
      locationName l `shouldBe` "Main Warehouse"
      locationType l `shouldBe` 1
