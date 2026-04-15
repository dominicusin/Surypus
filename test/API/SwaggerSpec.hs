{-# LANGUAGE OverloadedStrings #-}

module API.SwaggerSpec (spec) where

import qualified App
import qualified Data.Aeson as A
import qualified Data.ByteString.Lazy.Char8 as BL
import Test.Hspec
import Test.Hspec.Wai
import Test.MakeTest (makeApp)

spec :: Spec
spec = with makeApp $ do
  describe "GET /api/swagger.json" $ do
    it "returns 200" $ do
      get "/api/swagger.json" `shouldRespondWith` 200
    it "returns valid JSON" $ do
      r <- get "/api/swagger.json"
      let body = responseBody r
      case A.decode body :: Maybe A.Value of
        Nothing -> expectationFailure "Invalid JSON in swagger.json"
        Just _ -> return ()
    it "contains OpenAPI fields" $ do
      r <- get "/api/swagger.json"
      let body = BL.unpack (responseBody r)
      body `shouldContain` "\"openapi\""
      body `shouldContain` "\"paths\""
    it "contains health path" $ do
      r <- get "/api/swagger.json"
      let body = BL.unpack (responseBody r)
      body `shouldContain` "/api/v1/health"
      body `shouldContain` "/api/v1/bills"
    it "requires bearer security" $ do
      r <- get "/api/swagger.json"
      let body = BL.unpack (responseBody r)
      body `shouldContain` "bearerAuth"
      get "/api/swagger.json" `shouldRespondWith` 200
