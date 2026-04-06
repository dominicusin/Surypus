{-# LANGUAGE OverloadedStrings #-}

-- | Goods API
--
-- This module provides the goods/products API functionality for the ERP system.
module Surypus.API.Goods
  ( listGoods,
    createGoods,
    getGoods,
    updateGoods,
    deleteGoods,
    searchGoods,
  )
where

import qualified DAL.Mutations as M
import qualified DAL.Queries as Q
import DAL.Types
  ( Goods (..),
    GoodsFilter (..),
    GoodsInput (..),
    MutationResult (..),
    PaginatedResult (..),
    Pagination (..),
    QueryResult (..),
  )
import Data.Int (Int64)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Hasql.Pool (Pool)

listGoods :: Pool -> Maybe Text -> Maybe Text -> Maybe Text -> Maybe Int -> IO (QueryResult [Goods])
listGoods pool mName mBarcode mCode mLimit = do
  let filter' =
        GoodsFilter
          { gfName = mName,
            gfBarcode = mBarcode,
            gfCode = mCode
          }
      pagination =
        Pagination
          { pgLimit = fromMaybe 50 mLimit,
            pgOffset = 0
          }
  result <- Q.getGoodsPaginated pool filter' pagination Nothing Nothing
  case result of
    QuerySuccess (PaginatedResult goods _ _ _) -> pure (QuerySuccess goods)
    QueryError err -> pure (QueryError err)

createGoods :: Pool -> GoodsInput -> IO (QueryResult MutationResult)
createGoods pool input = M.createGoods pool input

getGoods :: Pool -> Int64 -> IO (QueryResult Goods)
getGoods = Q.getGoodsById

getGoodsByBarcode :: Pool -> Text -> IO (QueryResult Goods)
getGoodsByBarcode = Q.getGoodsByBarcode

updateGoods :: Pool -> Int64 -> GoodsInput -> IO (QueryResult MutationResult)
updateGoods pool gid input = M.updateGoods pool gid input

deleteGoods :: Pool -> Int64 -> IO (QueryResult MutationResult)
deleteGoods pool gid = M.deleteGoods pool gid

searchGoods :: Pool -> Text -> IO (QueryResult [Goods])
searchGoods pool query = do
  result <- Q.getGoods pool
  case result of
    QuerySuccess goods -> pure (QuerySuccess goods)
    QueryError err -> pure (QueryError err)
