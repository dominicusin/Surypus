{-# LANGUAGE OverloadedStrings #-}
module Surypus.API.IntegrationsSpec (spec) where

import Surypus.API.Integrations
import Test.Hspec

spec :: Spec
spec = describe "parseOFX" $ do
  it "rejects empty input" $ do
    let result = parseOFX ""
    result `shouldSatisfy` isLeft
  it "rejects missing required fields" $ do
    let result = parseOFX "<OFX><BANKID></BANKID></OFX>"
    result `shouldSatisfy` isLeft
  it "rejects malformed input" $ do
    let result = parseOFX "not-ofx"
    result `shouldSatisfy` isLeft
  it "parses valid OFX with required fields" $ do
    let result = parseOFX "<BANKID>123</BANKID>\n<ACCTID>456</ACCTID>\n<CURDEF>USD</CURDEF>"
    case result of
      Right stmt -> do
        bsBank stmt `shouldBe` "123"
        bsAccount stmt `shouldBe` "456"
        bsCurrency stmt `shouldBe` "USD"
        bsTransactions stmt `shouldBe` []
      Left _ -> expectationFailure "Expected Right"
  it "parses OFX with a transaction" $ do
    let input = "<BANKID>001</BANKID>\n<ACCTID>ACC-123</ACCTID>\n<CURDEF>EUR</CURDEF>\n<STMTTRN>\n<TRNTYPE>CREDIT</TRNTYPE>\n<TRNAMT>150.00</TRNAMT>\n<NAME>Payment</NAME>\n<MEMO>Invoice 42</MEMO>\n</STMTTRN>"
    let result = parseOFX input
    case result of
      Right stmt -> do
        length (bsTransactions stmt) `shouldBe` 1
        let txn = head (bsTransactions stmt)
        btType txn `shouldBe` Credit
        btAmount txn `shouldBe` 150.00
        btDescription txn `shouldBe` "Payment"
      Left _ -> expectationFailure "Expected Right"
  it "parses OFX with a debit transaction" $ do
    let input = "<BANKID>001</BANKID>\n<ACCTID>ACC-123</ACCTID>\n<CURDEF>USD</CURDEF>\n<STMTTRN>\n<TRNTYPE>DEBIT</TRNTYPE>\n<TRNAMT>75.50</TRNAMT>\n<NAME>Withdrawal</NAME>\n</STMTTRN>"
    let result = parseOFX input
    case result of
      Right stmt -> do
        length (bsTransactions stmt) `shouldBe` 1
        let txn = head (bsTransactions stmt)
        btType txn `shouldBe` Debit
        btAmount txn `shouldBe` 75.50
        btDescription txn `shouldBe` "Withdrawal"
      Left _ -> expectationFailure "Expected Right"
  it "handles multiple transactions" $ do
    let input = "<BANKID>001</BANKID>\n<ACCTID>ACC-123</ACCTID>\n<CURDEF>USD</CURDEF>\n<STMTTRN>\n<TRNTYPE>CREDIT</TRNTYPE>\n<TRNAMT>500</TRNAMT>\n<NAME>Deposit</NAME>\n</STMTTRN>\n<STMTTRN>\n<TRNTYPE>DEBIT</TRNTYPE>\n<TRNAMT>50</TRNAMT>\n<NAME>Fee</NAME>\n</STMTTRN>"
    let result = parseOFX input
    case result of
      Right stmt -> do
        length (bsTransactions stmt) `shouldBe` 2
      Left _ -> expectationFailure "Expected Right"

isLeft :: Either a b -> Bool
isLeft (Left _) = True
isLeft _ = False
