{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Payment
  ( listPayments,
    createPayment,
    getPayment,
    updatePayment,
    deletePayment,
  )
where

import DAL.Types (Payment (..), PaymentInput (..), QueryResult (..))
import DAL.Database (Pool)
import DAL.Queries (getPayments, getPaymentById)
import qualified DAL.Mutations as Mut
import Data.Int (Int64)
import qualified Data.Text as T

-- | List all payments using DAL.Queries
listPayments :: Pool -> IO (QueryResult [Payment])
listPayments pool = getPayments pool

-- | Create a new payment using DAL.Mutations
createPayment :: Pool -> PaymentInput -> IO (QueryResult Payment)
createPayment pool input = do
  result <- Mut.createPayment pool input
  case result of
    QuerySuccess _ -> getPayments pool
    QueryError err -> return $ QueryError err

-- | Get a specific payment by ID using DAL.Queries
getPayment :: Pool -> Int64 -> IO (QueryResult Payment)
getPayment pool pid = getPaymentById pool pid

-- | Update a payment using DAL.Mutations
updatePayment :: Pool -> Int64 -> PaymentInput -> IO (QueryResult Payment)
updatePayment pool pid input = do
  result <- Mut.updatePayment pool pid input
  case result of
    QuerySuccess _ -> getPaymentById pool pid
    QueryError err -> return $ QueryError err

-- | Delete a payment using DAL.Mutations
deletePayment :: Pool -> Int64 -> IO (QueryResult ())
deletePayment pool pid = do
  result <- Mut.deletePayment pool pid
  case result of
    QuerySuccess _ -> return $ QuerySuccess ()
    QueryError err -> return $ QueryError err