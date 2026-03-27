{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeFamilies #-}

module DAL.Repository
  ( Repository (..),
    RepositoryError (..),
    runRepository,
    transaction,
    fromQueryResult,
    fromQueryResultWith,
    isNotFoundMessage,
    fromValidation,
    findEntity,
    findAllEntities,
    createEntity,
    updateEntity,
    deleteEntity,
    queryWithFilter,
    paginate,
    HasRepository (..),
    MonadRepository (..),
    RepositoryT (..),
    RepositoryContext,
    defaultRepositoryContext,
  )
where

import Control.Monad.IO.Class (MonadIO, liftIO)
import Control.Monad.Trans.Class (MonadTrans (..))
import Control.Monad.Trans.Except (ExceptT (..), runExceptT, throwE)
import Control.Monad.Trans.Reader (ReaderT, asks, runReaderT)
import DAL.Types (QueryResult (..))
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)

-- ============================================================================
-- REPOSITORY ERRORS
-- ============================================================================

data RepositoryError
  = NotFound Text
  | DuplicateKey Text
  | ValidationError Text
  | DatabaseError Text
  | TransactionError Text
  deriving (Show, Eq)

-- ============================================================================
-- REPOSITORY CLASS
-- ============================================================================

class Repository repo entity | repo -> entity where
  find :: repo -> Int64 -> ExceptT RepositoryError IO (Maybe entity)
  findAll :: repo -> ExceptT RepositoryError IO [entity]
  create :: repo -> entity -> ExceptT RepositoryError IO entity
  update :: repo -> Int64 -> entity -> ExceptT RepositoryError IO entity
  delete :: repo -> Int64 -> ExceptT RepositoryError IO ()

-- ============================================================================
-- REPOSITORY CONTEXT
-- ============================================================================

newtype RepositoryContext = RepositoryContext
  {getPool :: Pool}

-- ============================================================================
-- REPOSITORY MONAD
-- ============================================================================

class (MonadIO m) => MonadRepository m where
  liftRepository :: ExceptT RepositoryError IO a -> m a

instance MonadRepository (ExceptT RepositoryError IO) where
  liftRepository = id

-- ============================================================================
-- REPOSITORY TRANSFORMATION
-- ============================================================================

newtype RepositoryT m a = RepositoryT
  {unRepositoryT :: ExceptT RepositoryError (ReaderT RepositoryContext m) a}
  deriving (Functor, Applicative, Monad, MonadIO)

instance MonadTrans RepositoryT where
  lift = RepositoryT . lift . lift

instance (MonadIO m) => MonadRepository (RepositoryT m) where
  liftRepository action = RepositoryT $ ExceptT $ lift $ liftIO (runExceptT action)

-- ============================================================================
-- RUN REPOSITORY
-- ============================================================================

runRepository :: RepositoryContext -> RepositoryT m a -> m (Either RepositoryError a)
runRepository ctx (RepositoryT action) = runReaderT (runExceptT action) ctx

-- ============================================================================
-- TRANSACTION SUPPORT
-- ============================================================================

transaction :: (Monad m) => RepositoryT m a -> RepositoryT m (Either RepositoryError a)
transaction action = RepositoryT $ ExceptT $ do
  result <- runExceptT (unRepositoryT action)
  pure (Right result)

fromQueryResult :: QueryResult a -> ExceptT RepositoryError IO a
fromQueryResult = fromQueryResultWith "Entity not found"

fromQueryResultWith :: Text -> QueryResult a -> ExceptT RepositoryError IO a
fromQueryResultWith notFoundMsg result = case result of
  QuerySuccess value -> pure value
  QueryError err
    | isNotFoundMessage err -> throwE (NotFound notFoundMsg)
    | otherwise -> throwE (DatabaseError err)

isNotFoundMessage :: Text -> Bool
isNotFoundMessage msg =
  let folded = T.toCaseFold msg
   in folded == "not found"
        || "no rows" `T.isInfixOf` folded
        || "unexpectedrowcountstatementerror" `T.isInfixOf` folded
        || "unexpected row count" `T.isInfixOf` folded

fromValidation :: Either [Text] a -> ExceptT RepositoryError IO a
fromValidation (Right value) = pure value
fromValidation (Left errors) = throwE (ValidationError (T.intercalate "; " errors))

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

findEntity :: (Repository repo entity, MonadRepository m) => repo -> Int64 -> m (Maybe entity)
findEntity repo id = liftRepository $ find repo id

findAllEntities :: (Repository repo entity, MonadRepository m) => repo -> m [entity]
findAllEntities repo = liftRepository $ findAll repo

createEntity :: (Repository repo entity, MonadRepository m) => repo -> entity -> m entity
createEntity repo entity = liftRepository $ create repo entity

updateEntity :: (Repository repo entity, MonadRepository m) => repo -> Int64 -> entity -> m entity
updateEntity repo id entity = liftRepository $ update repo id entity

deleteEntity :: (Repository repo entity, MonadRepository m) => repo -> Int64 -> m ()
deleteEntity repo id = liftRepository $ delete repo id

queryWithFilter :: (Repository repo entity, MonadRepository m) => repo -> (entity -> Bool) -> m [entity]
queryWithFilter repo predicate = do
  entities <- findAllEntities repo
  pure $ filter predicate entities

paginate :: (Repository repo entity, MonadRepository m) => repo -> Int -> Int -> m [entity]
paginate repo limit offset = do
  entities <- findAllEntities repo
  pure . take limit . drop offset $ entities

-- ============================================================================
-- DEFAULT CONTEXT
-- ============================================================================

defaultRepositoryContext :: Pool -> RepositoryContext
defaultRepositoryContext = RepositoryContext

-- ============================================================================
-- REPOSITORY HAS CLASS
-- ============================================================================

class HasRepository a repo | a -> repo where
  getRepository :: a -> repo

instance HasRepository RepositoryContext Pool where
  getRepository = getPool
