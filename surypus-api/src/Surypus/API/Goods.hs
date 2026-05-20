{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Goods
  ( listGoods,
    createGood,
    getGood,
    updateGood,
    deleteGood,
  )
where

import DAL.Types (Goods (..), GoodsInput (..), QueryResult (..))
import DAL.Database (Pool)
import DAL.Queries (getGoods, getGoodsById)
import DAL.Mutations (createGoods, updateGoods, deleteGoods)
import Data.Int (Int64)
import qualified Data.Text as T

-- | List all goods using DAL.Queries
listGoods :: Pool -> IO (QueryResult [Goods])
listGoods pool = getGoods pool

-- | Create a new good using DAL.Mutations
createGood :: Pool -> GoodsInput -> IO (QueryResult Goods)
createGood pool input = do
  result <- createGoods pool input
  case result of
    QuerySuccess _ -> do
      -- Fetch the created good to return full object
      case input of
        -- Note: Would need to fetch by code or return the created ID
        _ -> return $ QueryError "Created but cannot fetch"
    QueryError err -> return $ QueryError err

-- | Get a specific good by ID using DAL.Queries
getGood :: Pool -> Int64 -> IO (QueryResult Goods)
getGood pool gid = getGoodsById pool gid

-- | Update a good using DAL.Mutations
updateGood :: Pool -> Int64 -> GoodsInput -> IO (QueryResult Goods)
updateGood pool gid input = do
  result <- updateGoods pool gid input
  case result of
    QuerySuccess _ -> getGoodsById pool gid  -- Return updated object
    QueryError err -> return $ QueryError err

-- | Delete a good using DAL.Mutations
deleteGood :: Pool -> Int64 -> IO (QueryResult ())
deleteGood pool gid = do
  result <- deleteGoods pool gid
  case result of
    QuerySuccess _ -> return $ QuerySuccess ()
    QueryError err -> return $ QueryError err