{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}

-- | Generic Repository interface for DAL implementation
-- This module defines a typeclass-based repository pattern
-- that can be implemented with Hasql (or other DB backends).
module DAL.Repository where

import Hasql.Pool (Pool)
import Surypus.Error (AppError)

-- | Associated types provide entity-specific metadata
class Repository f entity | f -> entity where
  -- | ID type for the given entity
  type Id entity :: *

  -- | Pagination/filtering types for listing entities
  type Pagination entity :: *

  type Filters entity :: *

  -- | Find by primary key
  findById :: Pool -> Id entity -> IO (Either AppError (Maybe entity))

  -- | List with pagination/filters
  findAll :: Pool -> Pagination entity -> Filters entity -> IO (Either AppError [entity])

  -- | Create new entity
  create :: Pool -> entity -> IO (Either AppError entity)

  -- | Update existing entity by ID
  update :: Pool -> Id entity -> entity -> IO (Either AppError entity)

  -- | Delete by ID
  delete :: Pool -> Id entity -> IO (Either AppError ())
