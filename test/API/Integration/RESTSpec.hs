{-# LANGUAGE OverloadedStrings #-}

module API.Integration.RESTSpec where

import Test.Hspec
import qualified API.Integration.REST as REST
import Data.Aeson (Value, object, (.=))
import Data.Aeson.Key (fromString)
import qualified Data.Aeson.KeyMap as KM

spec :: Spec
spec = describe "API.Integration.REST" $ do
  describe "extractContent" $ do
    it "extracts content from JSON object" $ do
      let body = object ["content" .= ("test-content" :: String)]
      let result = REST.extractContent body
      result `shouldBe` "test-content"

    it "returns fallback when content is missing" $ do
      let body = object ["other" .= ("value" :: String)]
      let result = REST.extractContent body
      result `shouldBe` "sample-bank-statement-content"

    it "returns fallback for non-Object values" $ do
      let body = "string-value" :: Value
      let result = REST.extractContent body
      result `shouldBe` "sample-bank-statement-content"

  describe "extractFormat" $ do
    it "extracts format from JSON object" $ do
      let body = object ["format" .= ("ISO20022" :: String)]
      let result = REST.extractFormat body
      result `shouldBe` "ISO20022"

    it "returns OFX as default when format is missing" $ do
      let body = object ["other" .= ("value" :: String)]
      let result = REST.extractFormat body
      result `shouldBe` "OFX"

    it "returns OFX as default for non-Object values" $ do
      let body = "string-value" :: Value
      let result = REST.extractFormat body
      result `shouldBe` "OFX"
