{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Bills (
    listBills,
    createBill,
    getBill,
    updateBill,
    deleteBill,
    postBill,
)
where

import DAL.Database (ConnectionPool)
import qualified DAL.Mutations as Mut
import qualified DAL.Procedures as Proc
import qualified DAL.QueriesORM as ORM
import DAL.Types (Bill (..), BillInput (..), MutationResult (..), QueryResult (..))
import Data.Int (Int64)

listBills :: ConnectionPool -> IO (QueryResult [Bill])
listBills = ORM.getBills

createBill :: ConnectionPool -> BillInput -> IO (QueryResult MutationResult)
createBill = Mut.createBill

getBill :: ConnectionPool -> Int64 -> IO (QueryResult Bill)
getBill = ORM.getBillById

updateBill :: ConnectionPool -> Int64 -> BillInput -> IO (QueryResult Bill)
updateBill pool bid input = do
    result <- Mut.updateBill pool bid input
    case result of
        QuerySuccess _ -> ORM.getBillById pool bid
        QueryError err -> return $ QueryError err

deleteBill :: ConnectionPool -> Int64 -> IO (QueryResult ())
deleteBill pool bid = do
    result <- Mut.deleteBill pool bid
    case result of
        QuerySuccess _ -> return $ QuerySuccess ()
        QueryError err -> return $ QueryError err

postBill :: ConnectionPool -> Int64 -> IO (QueryResult ())
postBill pool bid = do
    result <- Proc.postBill pool bid
    case result of
        QuerySuccess True -> return $ QuerySuccess ()
        QuerySuccess False -> return $ QueryError "Failed to post bill: check bill status"
        QueryError err -> return $ QueryError err
