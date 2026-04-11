-- | Stock API
module Surypus.API.Stock
  ( listStock,
    getStockSummary,
    getStockByLocation,
    getStockByGoods,
  )
where

import qualified DAL.Queries as Q
import DAL.Types
  ( QueryResult (..),
  )
import Data.Int (Int64)
import Hasql.Pool (Pool)

listStock :: Pool -> IO (QueryResult [(Int64, Text, Int, Double, Double)])
listStock = Q.getStockSummary

getStockSummary :: Pool -> IO (QueryResult [(Int64, Text, Int, Double, Double)])
getStockSummary = Q.getStockSummary

getStockByLocation :: Pool -> Int64 -> IO (QueryResult [Stock])
getStockByLocation = Q.getStockByLocation

getStockByGoods :: Pool -> Int64 -> IO (QueryResult [Stock])
getStockByGoods = Q.getStockByGoods
