-- | Payment API
module Surypus.API.Payment
  ( listPayments,
    createPayment,
    getPayment,
    updatePayment,
    deletePayment,
  )
where

import qualified DAL.Mutations as M
import qualified DAL.Queries as Q
import DAL.Types
  ( MutationResult (..),
    Payment (..),
    PaymentInput (..),
    QueryResult (..),
  )
import Data.Int (Int64)
import Hasql.Pool (Pool)

listPayments :: Pool -> IO (QueryResult [Payment])
listPayments = Q.getPayments

createPayment :: Pool -> PaymentInput -> IO (QueryResult MutationResult)
createPayment = M.createPayment

getPayment :: Pool -> Int64 -> IO (QueryResult Payment)
getPayment = Q.getPaymentById

updatePayment :: Pool -> Int64 -> PaymentInput -> IO (QueryResult MutationResult)
updatePayment = M.updatePayment

deletePayment :: Pool -> Int64 -> IO (QueryResult MutationResult)
deletePayment = M.deletePayment
