{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}

module DAL.Repository where

import DAL.Types (Pagination (..))
import Data.Int (Int64)
import Data.Text (Text)
import Hasql.Pool (Pool)

-- Simple AppError used in repositories (placeholder for now)
data AppError = AppError Text deriving (Show, Eq)

-- Identity type family for entities
type family Id entity

-- Repository typeclass: parameterized by a repository tag `f` and the entity type `entity`.
-- This allows multiple repository implementations per entity while sharing a common API surface.
class Repository f entity where
  -- Find by ID
  findById :: Pool -> Id entity -> IO (Either AppError (Maybe entity))

  -- Find all with simple pagination (filters abstracted behind entity-specific types later)
  findAll :: Pool -> Pagination -> IO (Either AppError [entity])

  -- Create new entity
  create :: Pool -> entity -> IO (Either AppError entity)

  -- Update existing entity by ID
  update :: Pool -> Id entity -> entity -> IO (Either AppError entity)

  -- Delete entity by ID
  delete :: Pool -> Id entity -> IO (Either AppError ())
