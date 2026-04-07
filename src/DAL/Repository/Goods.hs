{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}

module DAL.Repository.Goods where

import DAL.Repository (AppError (..), Repository (..))
import DAL.Types (Goods (..))
import Data.Int (Int64)
import qualified Data.Text as T
import Hasql.Pool (Pool)

-- Simple repository tag for Goods
data GoodsRepo = GoodsRepo

type instance Id GoodsRepo = Int64

instance Repository GoodsRepo Goods where
  findById _pool _id = return (Left (AppError (T.pack "Not implemented")))
  findAll _pool _ = return (Left (AppError (T.pack "Not implemented")))
  create _pool _g = return (Left (AppError (T.pack "Not implemented")))
  update _pool _id _g = return (Left (AppError (T.pack "Not implemented")))
  delete _pool _id = return (Left (AppError (T.pack "Not implemented")))
