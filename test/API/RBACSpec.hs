{-# LANGUAGE OverloadedStrings #-}

module API.RBACSpec (spec) where

import qualified App
import Data.Aeson (object, (.=))
import Network.Wai (Application)
import RBACFixtures (expiredHeader, malformedHeader, withAdminUser, withOperatorUser, withViewerUser)
import Test.Hspec
import Test.Hspec.Wai
import Test.MakeTest (makeApp)

spec :: Spec
spec =
  with makeApp $ do
    describe "RBAC Authorization (HTTP)" $ do
      describe "GET /api/v1/bills (read:bills)" $ do
        it "admin can read bills" $ do
          h <- withAdminUser
          get "/api/v1/bills" [h] `shouldRespondWith` 200

        it "operator can read bills" $ do
          h <- withOperatorUser
          get "/api/v1/bills" [h] `shouldRespondWith` 200

        it "viewer can read bills" $ do
          h <- withViewerUser
          get "/api/v1/bills" [h] `shouldRespondWith` 200

        it "anonymous cannot read bills" $ do
          get "/api/v1/bills" [] `shouldRespondWith` 401

        describe "Edge cases" $ do
          it "rejects malformed token" $ do
            hdr <- malformedHeader
            get "/api/v1/bills" [hdr] `shouldRespondWith` 401
          it "rejects expired token" $ do
            hdr <- expiredHeader
            get "/api/v1/bills" [hdr] `shouldRespondWith` 401

      describe "POST /api/v1/bills (write:bills)" $ do
        let billData = object ["number" .= ("INV-001" :: String), "date" .= ("2026-04-12" :: String)]
        it "admin can create bills" $ do
          h <- withAdminUser
          post "/api/v1/bills" [h] billData `shouldRespondWith` 201

        it "operator cannot create bills" $ do
          h <- withOperatorUser
          post "/api/v1/bills" [h] billData `shouldRespondWith` 403

        it "viewer cannot create bills" $ do
          h <- withViewerUser
          post "/api/v1/bills" [h] billData `shouldRespondWith` 403

        it "anonymous cannot create bills" $ do
          post "/api/v1/bills" [] billData `shouldRespondWith` 401

      describe "DELETE /api/v1/bills/:id (delete:bills)" $ do
        it "admin can delete bills" $ do
          h <- withAdminUser
          delete "/api/v1/bills/1" [h] `shouldRespondWith` 204

        it "operator cannot delete bills" $ do
          h <- withOperatorUser
          delete "/api/v1/bills/1" [h] `shouldRespondWith` 403

        it "viewer cannot delete bills" $ do
          h <- withViewerUser
          delete "/api/v1/bills/1" [h] `shouldRespondWith` 403

          it "anonymous cannot delete bills" $ do
            delete "/api/v1/bills/1" [] `shouldRespondWith` 401

        describe "PUT /api/v1/payments/:id (update:payments)" $ do
          it "anonymous PUT -> 401" $ do
            let payload = object ["piAmount" .= (11.0 :: Double)]
            put "/api/v1/payments/1" [] payload `shouldRespondWith` 401
          it "admin PUT -> 200" $ do
            hdr <- withAdminUser
            let payload = object ["piAmount" .= (11.0 :: Double)]
            put "/api/v1/payments/1" [hdr] payload `shouldRespondWith` 200
          it "operator PUT -> 403" $ do
            hdr <- withOperatorUser
            let payload = object ["piAmount" .= (12.0 :: Double)]
            put "/api/v1/payments/1" [hdr] payload `shouldRespondWith` 403
          it "viewer PUT -> 403" $ do
            hdr <- withViewerUser
            let payload = object ["piAmount" .= (13.0 :: Double)]
            put "/api/v1/payments/1" [hdr] payload `shouldRespondWith` 403
        -- Edge-case RBAC: payments
        describe "Edge RBAC: payments" $ do
          it "anonymous cannot read payments" $ do
            get "/api/v1/payments" [] `shouldRespondWith` 401
          it "admin can read payments" $ do
            h <- withAdminUser
            get "/api/v1/payments" [h] `shouldRespondWith` 200
          it "anonymous cannot create payments" $ do
            post "/api/v1/payments" [] (object []) `shouldRespondWith` 401
          it "viewer cannot create payments" $ do
            h <- withViewerUser
            post "/api/v1/payments" [h] (object []) `shouldRespondWith` 403
          it "operator cannot create payments" $ do
            h <- withOperatorUser
            post "/api/v1/payments" [h] (object []) `shouldRespondWith` 403

        -- Edge-case RBAC: goods
        describe "Edge RBAC: goods" $ do
          it "anonymous cannot read goods" $ do
            get "/api/v1/goods" [] `shouldRespondWith` 401
          it "admin can read goods" $ do
            h <- withAdminUser
            get "/api/v1/goods" [h] `shouldRespondWith` 200
          it "anonymous cannot create goods" $ do
            post "/api/v1/goods" [] (object []) `shouldRespondWith` 401
          it "operator cannot create goods" $ do
            h <- withOperatorUser
            post "/api/v1/goods" [h] (object []) `shouldRespondWith` 403
          it "viewer cannot create goods" $ do
            h <- withViewerUser
            post "/api/v1/goods" [h] (object []) `shouldRespondWith` 403

        -- Edge-case RBAC: stock
        describe "Edge RBAC: stock" $ do
          it "anonymous cannot read stock" $ do
            get "/api/v1/stock" [] `shouldRespondWith` 401
          it "admin can read stock" $ do
            h <- withAdminUser
            get "/api/v1/stock" [h] `shouldRespondWith` 200
          it "operator cannot read stock (403)" $ do
            h <- withOperatorUser
            get "/api/v1/stock" [h] `shouldRespondWith` 403

        -- Edge-case RBAC: accounting
        describe "Edge RBAC: accounting" $ do
          it "anonymous cannot read accounting" $ do
            get "/api/v1/accounting/accounts" [] `shouldRespondWith` 401
          it "admin can read accounting" $ do
            h <- withAdminUser
            get "/api/v1/accounting/accounts" [h] `shouldRespondWith` 200

        describe "Edge RBAC: bills (PUT)" $ do
          it "anonymous PUT bills -> 401" $ do
            let payload = object ["number" .= ("INV-EDGE" :: String)]
            put "/api/v1/bills/1" [] payload `shouldRespondWith` 401
          it "admin PUT bills -> 200" $ do
            hdr <- withAdminUser
            let payload = object ["number" .= ("INV-EDGE2" :: String)]
            put "/api/v1/bills/1" [hdr] payload `shouldRespondWith` 200
          it "operator PUT bills -> 403" $ do
            hdr <- withOperatorUser
            let payload = object ["number" .= ("INV-EDGE3" :: String)]
            put "/api/v1/bills/1" [hdr] payload `shouldRespondWith` 403
          it "viewer PUT bills -> 403" $ do
            hdr <- withViewerUser
            let payload = object ["number" .= ("INV-EDGE4" :: String)]
            put "/api/v1/bills/1" [hdr] payload `shouldRespondWith` 403

        describe "Edge RBAC: payments" $ do
          it "GET payments anonymous 401" $ do
            get "/api/v1/payments" [] `shouldRespondWith` 401
          it "GET payments admin 200" $ do
            h <- withAdminUser
            get "/api/v1/payments" [h] `shouldRespondWith` 200
          it "POST payments anonymous 401" $ do
            post "/api/v1/payments" [] (object []) `shouldRespondWith` 401
          it "POST payments viewer 403" $ do
            h <- withViewerUser
            post "/api/v1/payments" [h] (object []) `shouldRespondWith` 403
          it "POST payments operator 403" $ do
            h <- withOperatorUser
            post "/api/v1/payments" [h] (object []) `shouldRespondWith` 403
          it "POST payments admin 201" $ do
            h <- withAdminUser
            let payload = object ["piBillId" .= (1 :: Int), "piAmount" .= (10.0 :: Double), "piPayDate" .= ("2026-04-12" :: String)]
            post "/api/v1/payments" [h] payload `shouldRespondWith` 201

        describe "PUT /api/v1/payments/:id (update:payments)" $ do
          it "anonymous PUT -> 401" $ do
            let payload = object ["piAmount" .= (11.0 :: Double)]
            put "/api/v1/payments/1" [] payload `shouldRespondWith` 401
          it "admin PUT -> 200" $ do
            hdr <- withAdminUser
            let payload = object ["piAmount" .= (11.0 :: Double)]
            put "/api/v1/payments/1" [hdr] payload `shouldRespondWith` 200
          it "operator PUT -> 403" $ do
            hdr <- withOperatorUser
            let payload = object ["piAmount" .= (12.0 :: Double)]
            put "/api/v1/payments/1" [hdr] payload `shouldRespondWith` 403
          it "viewer PUT -> 403" $ do
            hdr <- withViewerUser
            let payload = object ["piAmount" .= (13.0 :: Double)]
            put "/api/v1/payments/1" [hdr] payload `shouldRespondWith` 403

        describe "DELETE /api/v1/payments/:id (delete:payments)" $ do
          it "admin delete -> 204" $ do
            hdr <- withAdminUser
            delete "/api/v1/payments/1" [hdr] `shouldRespondWith` 204
          it "operator delete -> 403" $ do
            hdr <- withOperatorUser
            delete "/api/v1/payments/1" [hdr] `shouldRespondWith` 403
          it "viewer delete -> 403" $ do
            hdr <- withViewerUser
            delete "/api/v1/payments/1" [hdr] `shouldRespondWith` 403
          it "anonymous delete -> 401" $ do
            delete "/api/v1/payments/1" [] `shouldRespondWith` 401

        describe "Edge RBAC: goods" $ do
          it "GET goods anonymous 401" $ do
            get "/api/v1/goods" [] `shouldRespondWith` 401
          it "GET goods admin 200" $ do
            h <- withAdminUser
            get "/api/v1/goods" [h] `shouldRespondWith` 200
          it "POST goods anonymous 401" $ do
            post "/api/v1/goods" [] (object []) `shouldRespondWith` 401
          it "POST goods admin 201" $ do
            h <- withAdminUser
            let payload = object []
            post "/api/v1/goods" [h] payload `shouldRespondWith` 201
          it "POST goods operator 403" $ do
            h <- withOperatorUser
            post "/api/v1/goods" [h] (object []) `shouldRespondWith` 403
          it "POST goods viewer 403" $ do
            h <- withViewerUser
            post "/api/v1/goods" [h] (object []) `shouldRespondWith` 403

        describe "Edge RBAC: stock" $ do
          it "GET stock anonymous 401" $ do
            get "/api/v1/stock" [] `shouldRespondWith` 401
          it "GET stock admin 200" $ do
            h <- withAdminUser
            get "/api/v1/stock" [h] `shouldRespondWith` 200

        describe "Edge RBAC: accounting" $ do
          it "GET accounts anonymous 401" $ do
            get "/api/v1/accounting/accounts" [] `shouldRespondWith` 401
          it "GET accounts admin 200" $ do
            h <- withAdminUser
            get "/api/v1/accounting/accounts" [h] `shouldRespondWith` 200
