{-# LANGUAGE OverloadedStrings #-}

module API.ProcurementSpec (spec) where

import qualified App
import Data.Aeson (Value, object, (.=))
import Network.Wai (Application)
import Test.Hspec
import Test.Hspec.Wai
import Test.MakeTest (makeApp)

spec :: Spec
spec = do
  with makeApp $ do
    describe "GET /api/v1/procurement/demo" $ do
      it "should respond with 200" $ do
        get "/api/v1/procurement/demo" `shouldRespondWith` 200

-- Optionally verify JSON structure if API is extended
-- r <- get "/api/v1/procurement/demo"; (responseStatus r) `shouldBe` 200
