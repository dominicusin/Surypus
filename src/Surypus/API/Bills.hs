{-# LANGUAGE OverloadedStrings #-}

-- | Bills API
--
-- This module provides the bills/invoices API functionality for the ERP system.
module Surypus.API.Bills
  ( listBills,
    createBill,
    getBill,
    updateBill,
    deleteBill,
    getBillLines,
  )
where

import qualified DAL.Mutations as M
import qualified DAL.Queries as Q
import DAL.Types
  ( Bill (..),
    BillFilter (..),
    BillInput (..),
    BillLine (..),
    MutationResult (..),
    PaginatedResult (..),
    Pagination (..),
    QueryResult (..),
  )
import Data.Int (Int64)
import Data.Maybe (fromMaybe)
-- import Data.Text (Text)  -- unused, removed to satisfy -Werror
import Data.Time (Day)
import Hasql.Pool (Pool)

listBills :: Pool -> Maybe Int -> Maybe Int -> Maybe Int64 -> Maybe Day -> Maybe Day -> Maybe Int -> IO (QueryResult [Bill])
listBills pool mType mStatus mPerson mDateFrom mDateTo mLimit = do
  let filter' =
        BillFilter
          { bfBillType = mType,
            bfStatus = mStatus,
            bfPersonId = mPerson,
            bfDateFrom = mDateFrom,
            bfDateTo = mDateTo
          }
      pagination =
        Pagination
          { pgLimit = fromMaybe 50 mLimit,
            pgOffset = 0
          }
  result <- Q.getBillsPaginated pool filter' pagination Nothing Nothing
  case result of
    QuerySuccess (PaginatedResult bills _ _ _) -> pure (QuerySuccess bills)
    QueryError err -> pure (QueryError err)

createBill :: Pool -> BillInput -> IO (QueryResult MutationResult)
createBill = M.createBill

getBill :: Pool -> Int64 -> IO (QueryResult Bill)
getBill = Q.getBillById

updateBill :: Pool -> Int64 -> BillInput -> IO (QueryResult MutationResult)
updateBill _pool _bid _input = pure (QueryError "Not implemented")

deleteBill :: Pool -> Int64 -> IO (QueryResult MutationResult)
deleteBill = M.deleteBill

getBillLines :: Pool -> Int64 -> IO (QueryResult [BillLine])
getBillLines = Q.getBillLines
