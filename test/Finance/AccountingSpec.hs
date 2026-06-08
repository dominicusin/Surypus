{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Finance.AccountingSpec (spec) where

import Test.Hspec
import Test.QuickCheck
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

  describe "QuickCheck properties" $ do
    it "debit amount is always non-negative" $
      property prop_debit_nonnegative
    it "credit amount is always non-negative" $
      property prop_credit_nonnegative
    it "balance = debit - credit" $
      property prop_balance_formula
    it "balanced transaction passes validation" $
      property prop_balanced_passes
    it "unbalanced transaction fails validation" $
      property prop_unbalanced_fails
    it "mkTransaction succeeds for balanced entries" $
      property prop_mkTransaction_succeeds

-- | Generate non-negative Decimal
genDecimal :: Gen Decimal
genDecimal = fromIntegral <$> choose (0, 10000 :: Integer)

-- | Generate a balanced pair of ledger entries
genBalancedEntries :: Gen [LedgerEntry]
genBalancedEntries = do
  amount <- genDecimal
  return
    [ LedgerEntry Nothing (read "2024-01-15") 1 "Debit" amount (Decimal 0) Nothing
    , LedgerEntry Nothing (read "2024-01-15") 2 "Credit" (Decimal 0) amount Nothing
    ]

-- | Generate unbalanced ledger entries
genUnbalancedEntries :: Gen [LedgerEntry]
genUnbalancedEntries = do
  debitAmt <- choose (1, 10000 :: Integer)
  creditAmt <- suchThat (choose (1, 10000 :: Integer)) (/= debitAmt)
  return
    [ LedgerEntry Nothing (read "2024-01-15") 1 "Debit" (fromIntegral debitAmt) (Decimal 0) Nothing
    , LedgerEntry Nothing (read "2024-01-15") 2 "Credit" (Decimal 0) (fromIntegral creditAmt) Nothing
    ]

prop_debit_nonnegative :: Property
prop_debit_nonnegative = forAll genBalancedEntries $ \entries ->
  all (\(LedgerEntry _ _ _ _ d _ _) -> d >= 0) entries

prop_credit_nonnegative :: Property
prop_credit_nonnegative = forAll genBalancedEntries $ \entries ->
  all (\(LedgerEntry _ _ _ _ _ c _) -> c >= 0) entries

prop_balance_formula :: Property
prop_balance_formula = forAll genBalancedEntries $ \entries ->
  all (\le -> balance le == leDebit le - leCredit le) entries

prop_balanced_passes :: Property
prop_balanced_passes = forAll genBalancedEntries $ \entries ->
  let tx = Transaction Nothing (read "2024-01-15") "QC test" entries
  in isRight (validateTransaction tx)

prop_unbalanced_fails :: Property
prop_unbalanced_fails = forAll genUnbalancedEntries $ \entries ->
  let tx = Transaction Nothing (read "2024-01-15") "QC unbalanced" entries
  in isLeft (validateTransaction tx)

prop_mkTransaction_succeeds :: Property
prop_mkTransaction_succeeds = forAll genBalancedEntries $ \entries ->
  case mkTransaction Nothing (read "2024-01-15") "QC test" entries of
    Just _ -> True
    Nothing -> False

isJust :: Maybe a -> Bool
isJust (Just _) = True
isJust Nothing  = False

isRight :: Either a b -> Bool
isRight (Right _) = True
isRight _         = False

isLeft :: Either a b -> Bool
isLeft (Left _)  = True
isLeft _         = False
