{-# LANGUAGE OverloadedStrings #-}

-- | Accounting service layer (phase 1 skeleton)
module Service.AccountingService
  ( AccountingService (..),
    commitJournal,
  )
where

import Core.Accounting.Types (AccTurn)
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)

-- | Lightweight service container for accounting-related operations
data AccountingService = AccountingService
  { asPool :: Pool
  }

-- | Commit a single AccTurn into the ledger (stub for now)
commitJournal :: AccountingService -> AccTurn -> IO (Either Text ())
commitJournal _ _ = return (Right ())
