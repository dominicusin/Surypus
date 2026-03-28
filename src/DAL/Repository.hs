{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

module DAL.Repository
  ( Repository (..),
    RepositoryError (..),
    RepositoryT,
    HasRepository (..),
    isNotFoundMessage,
    runRepository,
    defaultRepositoryContext,
    RepositoryContext (..),
  )
where

import Control.Monad.Trans.Except (ExceptT, runExceptT)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)

data RepositoryError
  = NotFound Text
  | DatabaseError Text
  | ValidationError Text
  deriving (Show, Eq)

type RepositoryM = ExceptT RepositoryError IO

class Repository repo entity | repo -> entity where
  find :: repo -> Int64 -> RepositoryM (Maybe entity)
  findAll :: repo -> RepositoryM [entity]
  create :: repo -> entity -> RepositoryM Int64
  update :: repo -> Int64 -> entity -> RepositoryM (Maybe entity)
  delete :: repo -> Int64 -> RepositoryM (Maybe entity)

data RepositoryContext = RepositoryContext {rcPool :: Pool}

defaultRepositoryContext :: Pool -> RepositoryContext
defaultRepositoryContext = RepositoryContext

type RepositoryT = ExceptT RepositoryError

class HasRepository a pool | a -> pool where
  getRepository :: a -> pool

isNotFoundMessage :: Text -> Bool
isNotFoundMessage msg = "Not Found" `T.isInfixOf` msg

runRepository :: RepositoryContext -> RepositoryT IO a -> IO (Either RepositoryError a)
runRepository _ctx action = runExceptT action
