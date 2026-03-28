{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE KindSignatures #-}

module DAL.Repository
  ( Repository (..),
    Pagination (..),
    Filters (..),
    defaultPagination,
  )
where

import Data.Int (Int64)
import Hasql.Pool (Pool)

class Repository m entity | entity -> m where
  findById :: Pool -> Int64 -> m (Maybe entity)
  findAll :: Pool -> Pagination -> Filters -> m [entity]
  create :: Pool -> entity -> m Int64
  update :: Pool -> Int64 -> entity -> m Bool
  delete :: Pool -> Int64 -> m Bool

data Pagination = Pagination
  { pageOffset :: Int64,
    pageLimit :: Int64
  }
  deriving (Show, Eq)

defaultPagination :: Pagination
defaultPagination = Pagination 0 50

data Filters = Filters
  { filterText :: Maybe String,
    filterStatus :: Maybe Int
  }
  deriving (Show, Eq)
