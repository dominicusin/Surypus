{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}

module DAL.Repository.Person where

import DAL.Repository (AppError (..), Repository (..))
import DAL.Types (Person (..))
import Data.Int (Int64)
import qualified Data.Text as T
import Hasql.Pool (Pool)

-- Simple tag type for Person repository
data PersonRepo = PersonRepo

-- Associate Id type for Person
type instance Id PersonRepo = Int64

-- Minimal repository instance (not implemented yet; stubbed for wiring)
instance Repository PersonRepo Person where
  findById _pool _id = return (Left (AppError (T.pack "Not implemented")))
  findAll _pool _pagination = return (Left (AppError (T.pack "Not implemented")))
  create _pool _p = return (Left (AppError (T.pack "Not implemented")))
  update _pool _id _p = return (Left (AppError (T.pack "Not implemented")))
  delete _pool _id = return (Left (AppError (T.pack "Not implemented")))
