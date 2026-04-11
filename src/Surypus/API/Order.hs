-- | Order API
module Surypus.API.Order
  ( listOrders,
    getOrder,
  )
where

import qualified DAL.Queries as Q
import DAL.Types
  ( Order (..),
    QueryResult (..),
  )
import Data.Int (Int64)
import Hasql.Pool (Pool)

listOrders :: Pool -> IO (QueryResult [Order])
listOrders = Q.getOrders

getOrder :: Pool -> Int64 -> IO (QueryResult Order)
getOrder = Q.getOrderById
