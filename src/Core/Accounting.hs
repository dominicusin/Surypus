{-@ LIQUID "--reflection" @-}
{-@ LIQUID "--ple"        @-}
{-# LANGUAGE OverloadedStrings #-}

module Core.Accounting
  ( debit,
    credit,
    balance,
    LedgerEntry (..),
    Account (..),
    Transaction (..),
    validateTransaction,
    processTransaction,
  )
where

import Data.Int (Int64)
import Data.Text (Text, pack)
import Data.Time (Day)
import Surypus.Types (Decimal)

-- | Account in the chart of accounts
data Account = Account
  { accId :: Int64,
    accCode :: Text,
    accName :: Text,
    accType :: Text -- Asset, Liability, Equity, Revenue, Expense
  }
  deriving (Eq, Show)

-- | Single ledger entry (debit or credit)
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

-- | Transaction (collection of balanced entries)
data Transaction = Transaction
  { txId :: Maybe Int64,
    txDate :: Day,
    txDescription :: Text,
    txEntries :: [LedgerEntry]
  }
  deriving (Eq, Show)

-- | Extract debit amount from entry
debit :: LedgerEntry -> Decimal
debit = leDebit

-- | Extract credit amount from entry
credit :: LedgerEntry -> Decimal
credit = leCredit

-- | Calculate balance (debit - credit)
balance :: LedgerEntry -> Decimal
balance le = leDebit le - leCredit le

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
