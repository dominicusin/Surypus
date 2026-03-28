{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE ScopedTypeVariables #-}

module DAL.Repository
  ( Repository (..),
    RepositoryError (..),
    Pagination (..),
    Filters (..),
    defaultPagination,
  )
where

import Data.Int (Int64)
import Hasql.Pool (Pool)

data RepositoryError
  = NotFound String
  | DatabaseError String
  | ValidationError String
  deriving (Show, Eq)

class Repository m entity | entity -> m where
  findById :: Pool -> Int64 -> m (Maybe entity)
  findAll :: Pool -> Pagination -> Filters -> m [entity]
  create :: Pool -> entity -> m Int64
  update :: Pool -> Int64 -> entity -> m (Maybe entity)
  delete :: Pool -> Int64 -> m (Maybe entity)

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
