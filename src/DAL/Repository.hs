{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Generic Repository Pattern for Surypus ERP
--
-- This module provides a generic repository pattern implementation
-- for database access. It defines the core abstractions and error types
-- used throughout the DAL layer.
--
-- = Design
--
-- The repository pattern abstracts database operations, allowing:
--
-- * Easy mocking in tests
-- * Consistent error handling
-- * Reusable CRUD operations
-- * Type-safe database access
--
-- = Usage
--
-- @
-- import DAL.Repository
-- import DAL.Types
-- import Hasql.Pool
--
-- data MyEntity = MyEntity { ... }
--
-- instance Repository MyRepository MyEntity where
--   find repo id = ...
--   findAll repo = ...
--   create repo entity = ...
--   update repo id entity = ...
--   delete repo id = ...
-- @
module DAL.Repository
  ( -- * Core Types
    Repository (..),
    RepositoryError (..),
    RepositoryT,

    -- * Context Management
    RepositoryContext (..),
    defaultRepositoryContext,
    runRepository,

    -- * Type Classes
    HasRepository (..),

    -- * Helper Functions
    isNotFoundMessage,
  )
where

import Control.Monad.Trans.Except (ExceptT, runExceptT)
import DAL.Types (MutationResult (..), QueryResult (..))
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)

-- | Repository errors
data RepositoryError
  = NotFound Text
  | DatabaseError Text
  | ValidationError Text
  deriving (Show, Eq)

-- | Repository monad
type RepositoryM = ExceptT RepositoryError IO

-- | Repository class with functional dependency
-- | Each repository type is associated with exactly one entity type
class Repository repo entity | repo -> entity where
  find :: repo -> Int64 -> RepositoryM (Maybe entity)
  findAll :: repo -> RepositoryM [entity]
  create :: repo -> entity -> RepositoryM Int64
  update :: repo -> Int64 -> entity -> RepositoryM (Maybe entity)
  delete :: repo -> Int64 -> RepositoryM (Maybe entity)

-- | Repository context containing connection pool
newtype RepositoryContext = RepositoryContext {rcPool :: Pool}

-- | Create default repository context from pool
defaultRepositoryContext :: Pool -> RepositoryContext
defaultRepositoryContext = RepositoryContext

-- | Repository transformer
type RepositoryT m a = ExceptT RepositoryError m a

-- | Class for extracting repository from context
class HasRepository a pool | a -> pool where
  getRepository :: a -> pool

-- | Check if error message indicates not found
isNotFoundMessage :: Text -> Bool
isNotFoundMessage msg = "Not Found" `T.isInfixOf` msg

-- | Run repository action with context
runRepository :: RepositoryContext -> RepositoryT IO a -> IO (Either RepositoryError a)
runRepository _ctx = runExceptT
