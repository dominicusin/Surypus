{-# LANGUAGE OverloadedStrings #-}

module Integration.APICrudSpec.MakeTest where

import qualified App
import Data.Aeson (object, (.=))
import MakeTestSeed (seedDatabaseFromEnv)
import RBACFixtures (withAdminUser)
import Test.Hspec
import Test.Hspec.Wai
import Test.MakeTest (beforeAll)

spec :: Spec
spec = beforeAll seedDatabaseFromEnv $ describe "APICrud via MakeTest (HTTP)" $ do
  it "admin can create, read, update and delete a bill" $ do
    hdr <- withAdminUser
    -- Create
    let billPayload = object ["number" .= ("INV-MAKE-1" :: String), "date" .= ("2026-04-12" :: String)]
    post "/api/v1/bills" [hdr] billPayload `shouldRespondWith` 201
    -- Read
    get "/api/v1/bills" [hdr] `shouldRespondWith` 200
    -- Update
    let updatePayload = object ["number" .= ("INV-MAKE-1-UPDATED" :: String), "date" .= ("2026-04-13" :: String)]
    put "/api/v1/bills/1" [hdr] updatePayload `shouldRespondWith` 200
    -- Delete
    delete "/api/v1/bills/1" [hdr] `shouldRespondWith` 204
