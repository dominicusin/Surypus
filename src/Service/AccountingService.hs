{-# LANGUAGE RecordWildCards #-}

module Service.AccountingService
  ( AccountingService (..),
    createAccountingService,
    processTransaction,
    getAccountBalance,
    generateLedger,
  )
where

import DAL.Repository.AccPlan (AccPlanRepository)
import DAL.Repository.AccTurn (AccTurnRepository)
import Data.Int (Int64)
import Data.Text (Text)

-- | Accounting service for double-entry bookkeeping
data AccountingService = AccountingService
  { asAccPlanRepo :: AccPlanRepository,
    asAccTurnRepo :: AccTurnRepository
  }

-- | Create accounting service
createAccountingService :: AccPlanRepository -> AccTurnRepository -> AccountingService
createAccountingService = AccountingService

-- | Process a financial transaction (double-entry)
processTransaction :: AccountingService -> Transaction -> IO (Either Text TransactionResult)
processTransaction service transaction = do
  -- Validate transaction: debit == credit
  let totalDebit = sum $ map entryAmount $ filter (\e -> entryType e == Debit) (tEntries transaction)
      totalCredit = sum $ map entryAmount $ filter (\e -> entryType e == Credit) (tEntries transaction)

  if totalDebit /= totalCredit
    then pure $ Left "Transaction violates double-entry principle: debit != credit"
    else do
      -- Save transaction entries
      -- Implementation placeholder
      pure $ Right TransactionProcessed

-- | Get account balance
getAccountBalance :: AccountingService -> Int64 -> IO (Either Text Decimal)
getAccountBalance service accountId = do
  -- Calculate balance from ledger entries
  -- Implementation placeholder
  pure $ Right 0

-- | Generate ledger report
generateLedger :: AccountingService -> IO (Either Text Ledger)
generateLedger service = do
  -- Generate ledger from all entries
  -- Implementation placeholder
  pure $ Right emptyLedger

-- Data types (placeholders)
data Transaction = Transaction
  { tId :: Int64,
    tDate :: Day,
    tDescription :: Text,
    tEntries :: [Entry]
  }

data Entry = Entry
  { entryAccountId :: Int64,
    entryAmount :: Decimal,
    entryType :: EntryType
  }

data EntryType = Debit | Credit

data TransactionResult = TransactionProcessed

type Decimal = Double

type Day = ()

emptyLedger :: Ledger
emptyLedger = Ledger []

data Ledger = Ledger [Entry]
