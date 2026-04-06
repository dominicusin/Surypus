{-# LANGUAGE OverloadedStrings #-}

-- | Documents Bills API
--
-- This module provides bill document generation and management.
module Surypus.API.Documents.Bills
  ( generateBillDocument,
    BillDocument (..),
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Time (Day, getCurrentTime, utctDay)

data BillDocument = BillDocument
  { bdId :: Int64,
    bdBillId :: Int64,
    bdContent :: Text,
    bdGeneratedAt :: Day
  }
  deriving (Show, Eq)

generateBillDocument :: Int64 -> IO BillDocument
generateBillDocument billId = do
  now <- getCurrentTime
  pure $
    BillDocument
      { bdId = 0,
        bdBillId = billId,
        bdContent = "Bill document placeholder",
        bdGeneratedAt = utctDay now
      }
