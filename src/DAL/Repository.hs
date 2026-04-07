{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies #-}

module DAL.Repository
  ( AppError (..),
    RepositoryError (..),
    HasRepository (..),
    RepositoryT,
    Id,
    isNotFoundMessage,
    Repository (..),
    module DAL.Types,
  )
where

import Control.Monad.Trans.Except (ExceptT)
import DAL.Types (Pagination (..))
import Data.Int ()
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)

-- | Simple AppError used in repositories
data AppError = AppError Text deriving (Show, Eq)

-- | Repository-level errors (more specific than AppError)
data RepositoryError
  = NotFound Text
  | DatabaseError Text
  | ValidationError Text
  | ConstraintError Text
  deriving (Show, Eq)

-- | Class for repositories that can be run
class HasRepository repo pool | repo -> pool where
  getPool :: repo -> pool

-- | Repository transformer (simple wrapper around ExceptT)
type RepositoryT m a = ExceptT RepositoryError m a

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

-- | Helper to check if an error message indicates "not found"
isNotFoundMessage :: Text -> Bool
isNotFoundMessage msg = T.isInfixOf (T.pack "not found") (T.toLower msg)
