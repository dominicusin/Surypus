{-# LANGUAGE OverloadedStrings #-}

module Domain.DocumentSpec (spec_documentStatus) where

import Test.Hspec
import Core.Document.Types (DocumentRegister(..), DocumentRegisterStatus(..))
import Domain.Document (documentRegisterStatusAsOf)
import Data.Time (fromGregorian)

spec_documentStatus :: Spec
spec_documentStatus = describe "documentRegisterStatusAsOf" $ do
  let today = fromGregorian 2025 1 1
  let base = DocumentRegister
        { drId = Just 1
        , drPersonId = 1
        , drTypeId = 1
        , drSeries = Nothing
        , drNumber = "DOC-1"
        , drIssueDate = today
        , drExpiryDate = Nothing
        , drIssuer = Nothing
        , drFlags = 0
        }
  it "returns unlimited if expiry missing" $ do
    documentRegisterStatusAsOf today base `shouldBe` DocumentStatusUnlimited

  it "returns active if expiry on or after the reference date" $ do
    let reg = base { drExpiryDate = Just today }
    documentRegisterStatusAsOf today reg `shouldBe` DocumentStatusActive

  it "returns expired if expiry before the reference date" $ do
    let reg = base { drExpiryDate = Just (fromGregorian 2024 12 31) }
    documentRegisterStatusAsOf today reg `shouldBe` DocumentStatusExpired
