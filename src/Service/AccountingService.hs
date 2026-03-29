{-# LANGUAGE RecordWildCards #-}

module Service.AccountingService
  ( AccountingService (..),
    createAccountingService,
    processTransaction,
    getAccountBalance,
    getAccountTurnovers,
    generateLedger,
    validateTransaction,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day)
import Hasql.Pool (Pool)

data AccountingService = AccountingService
  {asPool :: Pool}

createAccountingService :: Pool -> AccountingService
createAccountingService = AccountingService

processTransaction :: AccountingService -> Transaction -> IO (Either Text TransactionResult)
processTransaction _ _ = pure $ Left "Not implemented"

getAccountBalance :: AccountingService -> Int64 -> IO (Either Text Double)
getAccountBalance _ _ = pure $ Left "Not implemented"

getAccountTurnovers :: AccountingService -> Int64 -> Day -> Day -> IO (Either Text Turnovers)
getAccountTurnovers _ _ _ _ = pure $ Left "Not implemented"

generateLedger :: AccountingService -> Day -> Day -> IO (Either Text Ledger)
generateLedger _ _ _ = pure $ Left "Not implemented"

validateTransaction :: Transaction -> Either Text ()
validateTransaction _ = Right ()

data Transaction = Transaction
  { tDate :: Day,
    tDescription :: Text,
    tEntries :: [Entry]
  }

data Entry = Entry
  { entryAccountId :: Int64,
    entryAmount :: Double,
    entryType :: EntryType
  }

data EntryType = Debit | Credit

data TransactionResult = TransactionProcessed Int64

data Ledger = Ledger {ledgerEntries :: [LedgerEntry]}

data LedgerEntry = LedgerEntry

data Turnovers = Turnovers
  { trDebitTurnover :: Double,
    trCreditTurnover :: Double,
    trOpeningBalance :: Double,
    trClosingBalance :: Double
  }
