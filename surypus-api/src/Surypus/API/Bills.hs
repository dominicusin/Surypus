{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Bills
  ( listBills,
    createBill,
    getBill,
    updateBill,
    deleteBill,
    postBill,
  )
where

import DAL.Types (Bill (..), BillInput (..), QueryResult (..), MutationResult (..))
import DAL.Database (Pool)
import DAL.Queries (getBills, getBillById)
import qualified DAL.Mutations as Mut
import qualified DAL.Procedures as Proc
import Data.Int (Int64)


-- | List bills using DAL.Queries
listBills :: Pool -> IO (QueryResult [Bill])
listBills pool = getBills pool

-- | Create bill using DAL.Mutations
createBill :: Pool -> BillInput -> IO (QueryResult MutationResult)
createBill = Mut.createBill

-- | Get bill by ID using DAL.Queries
getBill :: Pool -> Int64 -> IO (QueryResult Bill)
getBill pool bid = getBillById pool bid

-- | Update bill using DAL.Mutations
updateBill :: Pool -> Int64 -> BillInput -> IO (QueryResult Bill)
updateBill pool bid input = do
  result <- Mut.updateBill pool bid input
  case result of
    QuerySuccess _ -> getBillById pool bid
    QueryError err -> return $ QueryError err

-- | Delete bill using DAL.Mutations
deleteBill :: Pool -> Int64 -> IO (QueryResult ())
deleteBill pool bid = do
  result <- Mut.deleteBill pool bid
  case result of
    QuerySuccess _ -> return $ QuerySuccess ()
    QueryError err -> return $ QueryError err

-- | Post bill - updates status to posted and creates accounting entries
postBill :: Pool -> Int64 -> IO (QueryResult ())
postBill pool bid = do
  result <- Proc.postBill pool bid
  case result of
    QuerySuccess True -> return $ QuerySuccess ()
    QuerySuccess False -> return $ QueryError "Failed to post bill: check bill status"
    QueryError err -> return $ QueryError err
