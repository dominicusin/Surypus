{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}

module DAL.Repository.Goods
  ( GoodsRepo,
    Id,
  )
where

import DAL.Repository (AppError (..), Id)
import DAL.Types (Goods (..))
import Data.Int (Int64)
import qualified Data.Text as T
import Hasql.Pool (Pool)

data GoodsRepo = GoodsRepo

type instance Id GoodsRepo = Int64

goodsFindById :: Pool -> Int64 -> IO (Either AppError (Maybe Goods))
goodsFindById _pool _id = return (Left (AppError (T.pack "Not implemented")))
