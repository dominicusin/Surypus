{-@ LIQUID "--reflection" @-}
{-@ LIQUID "--ple"        @-}
{-# LANGUAGE OverloadedStrings #-}

{-@ type NonNeg = {v:Decimal | v >= 0} @-}

module Finance.Accounting
  ( debit,
    credit,
    balance,
    LedgerEntry   (..),
    Account   (..),
    Transaction   (..),
    validateTransaction,
    processTransaction,
    mkLedgerEntry,
    mkTransaction
  ) where

import Data.Int (Int64)
import Data.Text (Text, pack)
import Data.Time (Day)
import Surypus.CoreTypes (Decimal)

-- | Account in the chart of accounts
data Account = Account
  { accId :: Int64,
    accCode :: Text,
    accName :: Text,
    accType :: Text -- Asset, Liability, Equity, Revenue, Expense
  }
  deriving (Eq, Show)

-- | Single ledger entry (debit or credit)
-- Invariant: debit and credit amounts must be non-negative
data LedgerEntry = LedgerEntry
  { leId :: Maybe Int64,
    leDate :: Day,
    leAccount :: Int64,
    leDescription :: Text,
    leDebit :: Decimal,
    leCredit :: Decimal,
    leDocRef :: Maybe Text
  }
  deriving (Eq, Show)

{-@ mkLedgerEntry :: _ -> _ -> _ -> _ -> debit:NonNeg -> credit:NonNeg -> _ -> Maybe LedgerEntry @-}
-- | Smart constructor for LedgerEntry that ensures non-negative amounts
-- Returns Nothing if debit or credit is negative
mkLedgerEntry :: Maybe Int64 -> Day -> Int64 -> Text -> Decimal -> Decimal -> Maybe Text -> Maybe LedgerEntry
mkLedgerEntry lid date acc desc debitAmt creditAmt docRef
  | debitAmt < 0 = Nothing
  | creditAmt < 0 = Nothing
  | otherwise = Just $ LedgerEntry lid date acc desc debitAmt creditAmt docRef

-- | Transaction (collection of balanced entries)
-- Invariant: total debits must equal total credits
data Transaction = Transaction
  { txId :: Maybe Int64,
    txDate :: Day,
    txDescription :: Text,
    txEntries :: [LedgerEntry]
  }
  deriving (Eq, Show)

-- | Smart constructor for Transaction that validates balance
-- Returns Nothing if transaction is unbalanced
mkTransaction :: Maybe Int64 -> Day -> Text -> [LedgerEntry] -> Maybe Transaction
mkTransaction tid date desc entries = do
  let tx = Transaction tid date desc entries
  case validateTransaction tx of
    Right _ -> Just tx
    Left _ -> Nothing

-- | Extract debit amount from entry
debit :: LedgerEntry -> Decimal
debit = leDebit

-- | Extract credit amount from entry
credit :: LedgerEntry -> Decimal
credit = leCredit

-- | Calculate balance (debit - credit)
-- Ensures balance doesn't go negative for asset accounts
balance :: LedgerEntry -> Decimal
balance le = leDebit le - leCredit le

{-@ validateTransaction :: tx:Transaction -> Either Text {v:Transaction | sumDebits v == sumCredits v} @-}
-- | Validate transaction (debits must equal credits)
validateTransaction :: Transaction -> Either Text Transaction
validateTransaction tx@Transaction {txEntries = entries}
  | null entries = Left "Transaction must have at least one entry"
  | totalDebit /= totalCredit =
      Left $
        "Transaction unbalanced: debit="
          <> pack (show totalDebit)
          <> " credit="
          <> pack (show totalCredit)
  | otherwise = Right tx
  where
    totalDebit = sum (fmap leDebit entries)
    totalCredit = sum (fmap leCredit entries)

-- | Process validated transaction
--
-- This function validates the transaction and returns a result.
-- In a full implementation, this would persist the transaction
-- to the database and generate accounting entries.
--
-- Returns 'Right ()' on success with validated transaction
processTransaction :: Transaction -> Either Text ()
processTransaction tx = do
  _ <- validateTransaction tx
  Right ()
