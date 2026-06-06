{-# LANGUAGE OverloadedStrings #-}

module Finance.AccountingSpec (spec) where

import Test.Hspec
import Finance.Accounting
import Surypus.CoreTypes (Decimal(..))

spec :: Spec
spec = do
  describe "mkTransaction" $ do
    it "creates a transaction with balanced entries" $
      mkTransaction Nothing (read "2024-01-15") "Test tx"
        [ LedgerEntry Nothing (read "2024-01-15") 1 "Debit" (Decimal 100) (Decimal 0) Nothing
        , LedgerEntry Nothing (read "2024-01-15") 2 "Credit" (Decimal 0) (Decimal 100) Nothing
        ] `shouldSatisfy` isJust

    it "rejects unbalanced transaction" $
      mkTransaction Nothing (read "2024-01-15") "Unbalanced"
        [ LedgerEntry Nothing (read "2024-01-15") 1 "Debit" (Decimal 100) (Decimal 0) Nothing
        , LedgerEntry Nothing (read "2024-01-15") 2 "Credit" (Decimal 0) (Decimal 50) Nothing
        ] `shouldBe` Nothing

    it "rejects transaction with no entries" $
      mkTransaction Nothing (read "2024-01-15") "Empty" [] `shouldBe` Nothing

  describe "validateTransaction" $ do
    it "passes for balanced entries" $ do
      let tx = Transaction Nothing (read "2024-01-15") "Test"
                [ LedgerEntry Nothing (read "2024-01-15") 1 "Debit" (Decimal 200) (Decimal 0) Nothing
                , LedgerEntry Nothing (read "2024-01-15") 2 "Credit" (Decimal 0) (Decimal 200) Nothing
                ]
      validateTransaction tx `shouldSatisfy` isRight

    it "fails when debits != credits" $ do
      let tx = Transaction Nothing (read "2024-01-15") "Test"
                [ LedgerEntry Nothing (read "2024-01-15") 1 "Debit" (Decimal 300) (Decimal 0) Nothing
                , LedgerEntry Nothing (read "2024-01-15") 2 "Credit" (Decimal 0) (Decimal 100) Nothing
                ]
      validateTransaction tx `shouldSatisfy` isLeft

    it "fails for empty entries" $ do
      let tx = Transaction Nothing (read "2024-01-15") "Empty" []
      validateTransaction tx `shouldSatisfy` isLeft

  describe "debit / credit / balance" $ do
    it "debit returns the debit amount" $
      debit (LedgerEntry Nothing (read "2024-01-15") 1 "D" (Decimal 50) (Decimal 0) Nothing)
        `shouldBe` Decimal 50

    it "credit returns the credit amount" $
      credit (LedgerEntry Nothing (read "2024-01-15") 1 "C" (Decimal 0) (Decimal 30) Nothing)
        `shouldBe` Decimal 30

    it "balance = debit - credit" $
      balance (LedgerEntry Nothing (read "2024-01-15") 1 "B" (Decimal 100) (Decimal 40) Nothing)
        `shouldBe` Decimal 60

  describe "processTransaction" $ do
    it "processes a valid balanced transaction" $
      processTransaction
        (Transaction Nothing (read "2024-01-15") "Test"
          [ LedgerEntry Nothing (read "2024-01-15") 1 "Debit" (Decimal 100) (Decimal 0) Nothing
          , LedgerEntry Nothing (read "2024-01-15") 2 "Credit" (Decimal 0) (Decimal 100) Nothing
          ]) `shouldBe` Right ()

    it "rejects unbalanced transaction" $
      processTransaction
        (Transaction Nothing (read "2024-01-15") "Test"
          [ LedgerEntry Nothing (read "2024-01-15") 1 "Debit" (Decimal 50) (Decimal 0) Nothing
          , LedgerEntry Nothing (read "2024-01-15") 2 "Credit" (Decimal 0) (Decimal 25) Nothing
          ]) `shouldSatisfy` isLeft

  describe "double-entry invariant" $ do
    it "multiple entries with balanced totals pass validation" $ do
      let tx = Transaction Nothing (read "2024-01-15") "Multi-entry"
                [ LedgerEntry Nothing (read "2024-01-15") 1 "Cash" (Decimal 500) (Decimal 0) Nothing
                , LedgerEntry Nothing (read "2024-01-15") 2 "Revenue" (Decimal 0) (Decimal 300) Nothing
                , LedgerEntry Nothing (read "2024-01-15") 3 "Tax payable" (Decimal 0) (Decimal 200) Nothing
                ]
      validateTransaction tx `shouldSatisfy` isRight

    it "round-tripping: mkTransaction + processTransaction" $ do
      let mtx = mkTransaction Nothing (read "2024-06-01") "Roundtrip"
                  [ LedgerEntry Nothing (read "2024-06-01") 1 "Debit" (Decimal 1000) (Decimal 0) Nothing
                  , LedgerEntry Nothing (read "2024-06-01") 2 "Credit" (Decimal 0) (Decimal 1000) Nothing
                  ]
      case mtx of
        Just tx -> processTransaction tx `shouldBe` Right ()
        Nothing -> expectationFailure "mkTransaction returned Nothing"

isJust :: Maybe a -> Bool
isJust (Just _) = True
isJust Nothing  = False

isRight :: Either a b -> Bool
isRight (Right _) = True
isRight _         = False

isLeft :: Either a b -> Bool
isLeft (Left _)  = True
isLeft _         = False
