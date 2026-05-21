{-# LANGUAGE OverloadedStrings #-}
module Surypus.AITest where

import Test.Hspec
import Data.Aeson
import qualified Data.Text as T
import Surypus.API.AI

spec :: Spec
spec = describe "AI API types" $ do
  it "encodes AIDocumentParseRequest correctly" $ do
    let req = AIDocumentParseRequest "invoice content" "invoice"
    encode req `shouldBe` object ["aipDocContent" .= ("invoice content" :: T.Text), "aipDocType" .= ("invoice" :: T.Text)]

  it "decodes AIDocumentParseResponse with all fields" $ do
    let json = object
          [ "aiprVendor" .= ("Acme Corp" :: T.Text)
          , "aiprInvoiceNumber" .= ("INV-001" :: T.Text)
          , "aiprInvoiceDate" .= ("2024-01-15" :: T.Text)
          , "aiprDueDate" .= ("2024-02-15" :: T.Text)
          , "aiprTotalAmount" .= (100.50 :: Double)
          , "aiprLineItems" .= ([] :: [Value])
          , "aiprRawJson" .= object []
          ] :: Value
    case fromJSON (Object json) of
      Error _ -> expectationFailure "Failed to decode"
      Success resp -> do
        aiprVendor resp `shouldBe` Just "Acme Corp"
        aiprInvoiceNumber resp `shouldBe` Just "INV-001"
        aiprTotalAmount resp `shouldBe` Just 100.50

  it "decodes AIDocumentParseResponse with missing fields" $ do
    let json = object [] :: Value
    case fromJSON (Object json) of
      Error _ -> expectationFailure "Failed to decode"
      Success resp -> do
        aiprVendor resp `shouldBe` Nothing
        aiprTotalAmount resp `shouldBe` Nothing