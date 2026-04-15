{-# LANGUAGE OverloadedStrings #-}

module API.HealthSpec (spec) where

import qualified App
import Data.Aeson (Value (..))
import qualified Data.Aeson as A
import qualified Data.ByteString.Lazy as BL
import qualified Data.HashMap.Strict as HM
import qualified Data.Text as T
import Test.Hspec
import Test.Hspec.Wai
import Test.MakeTest (makeApp)

spec :: Spec
spec = with makeApp $ do
  describe "GET /api/v1/health" $ do
    it "returns 200" $ do
      get "/api/v1/health" `shouldRespondWith` 200
    it "response contains status and db fields" $ do
      r <- get "/api/v1/health"
      let mb = A.decode (BL.fromStrict (BL.toStrict (responseBody r))) :: Maybe Value
      case mb of
        Nothing -> expectationFailure "Invalid JSON"
        Just (Object o) -> do
          case HM.lookup ("status") o of
            Just (A.String s) -> s `shouldBe` "ok"
            _ -> expectationFailure "missing status field"
          case HM.lookup ("checks") o of
            Just (A.Object checks) -> do
              case HM.lookup ("db") checks of
                Just (A.String dbs) -> dbs `shouldBe` "ok"
                _ -> expectationFailure "missing db in checks"
            _ -> expectationFailure "missing checks object"
        _ -> expectationFailure "health not an object"
    it "is publicly accessible" $ do
      get "/api/v1/health" `shouldRespondWith` 200
