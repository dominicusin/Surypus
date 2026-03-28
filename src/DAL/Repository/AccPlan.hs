{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Accounting Plan repository interface and implementation.
--
-- This module defines the repository pattern for Accounting Plan entities, providing
-- CRUD operations and query functions. It abstracts the database access
-- layer and allows for easy mocking in tests.
--
-- The repository is parameterized over a pool type, allowing different
-- connection pool implementations to be used.
--
-- === Examples
--
-- Creating a repository and finding an accounting plan by ID:
-- @
-- import DAL.Repository.AccPlan (AccPlanRepository, mkAccPlanRepository, runAccPlanRepository)
-- import DAL.Types (AccPlan)
-- import Hasql.Pool (Pool)
--
-- -- Assuming you have a connection pool
-- let pool :: Pool = undefined -- TODO: Initialize pool
-- let repo :: AccPlanRepository = mkAccPlanRepository pool
--
-- -- Find an accounting plan by ID
-- result <- runAccPlanRepository repo $ find 123
-- case result of
--   Right (Just plan) -> print (plan :: AccPlan)
--   Right Nothing  -> putStrLn "Accounting plan not found"
--   Left err       -> putStrLn $ "Error: " ++ err
-- @
--
-- Listing all accounting plans:
-- @
-- import DAL.Repository.AccPlan (AccPlanRepository, mkAccPlanRepository, runAccPlanRepository)
-- import Hasql.Pool (Pool)
--
-- -- Assuming you have a connection pool
-- let pool :: Pool = undefined -- TODO: Initialize pool
-- let repo :: AccPlanRepository = mkAccPlanRepository pool
--
-- result <- runAccPlanRepository repo $ listAccPlansRepo
-- case result of
--   Right plans -> mapM_ print plans
--   Left err       -> putStrLn $ "Error: " ++ err
-- @
--
-- Creating a new accounting plan:
-- @
-- import DAL.Repository.AccPlan (AccPlanRepository, mkAccPlanRepository, runAccPlanRepository)
-- import DAL.Types (AccPlanInput)
-- import Hasql.Pool (Pool)
--
-- -- Assuming you have a connection pool
-- let pool :: Pool = undefined -- TODO: Initialize pool
-- let repo :: AccPlanRepository = mkAccPlanRepository pool
-- let input = AccPlanInput
--       { apiCode = "TEST"
--       , apiName = "Test Plan"
--       , apiType = 1
--       , apiParentCode = Nothing
--       , apiKind = 0
--       , apiIsAnalytical = False
--       }
--
-- result <- runAccPlanRepository repo $ createAccPlanRepo input
-- case result of
--   Right planId -> putStrLn $ "Created plan with ID: " ++ show planId
--   Left err     -> putStrLn $ "Error: " ++ err
-- @
module DAL.Repository.AccPlan
  ( AccPlanRepository (..),
    HasAccPlanRepository (..),
    mkAccPlanRepository,
    runAccPlanRepository,
    listAccPlansRepo,
    createAccPlanRepo,
    updateAccPlanRepo,
    deleteAccPlanRepo,
  )
where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.Except (ExceptT, throwE)
import DAL.Mutations (createAccPlan, deleteAccPlan, updateAccPlan)
import DAL.Queries (getAccPlanById, getAccPlans)
import DAL.Repository
import DAL.Types
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)
import qualified Surypus.Validation as Validation

data AccPlanRepository = AccPlanRepository
  { aprPool :: Pool
  }

instance Repository AccPlanRepository AccPlan where
  find repo planId = do
    result <- liftIO $ getAccPlanById (aprPool repo) planId
    case result of
      QuerySuccess plan -> pure (Just plan)
      QueryError err
        | isNotFoundMessage err -> pure Nothing
        | otherwise -> throwE (DatabaseError err)

  findAll repo = do
    result <- liftIO $ getAccPlans (aprPool repo)
    case result of
      QuerySuccess plans -> pure plans
      QueryError err -> throwE (DatabaseError err)

  create repo plan = do
    created <- createAccPlanRepo repo (toAccPlanInput plan)
    pure (apId created)

  update repo planId plan = do
    updated <- updateAccPlanRepo repo planId (toAccPlanInput plan)
    pure (Just updated)

  delete repo planId = do
    deleteAccPlanRepo repo planId
    pure Nothing

listAccPlansRepo :: AccPlanRepository -> ExceptT RepositoryError IO [AccPlan]
listAccPlansRepo = findAll

createAccPlanRepo :: AccPlanRepository -> AccPlanInput -> ExceptT RepositoryError IO AccPlan
createAccPlanRepo repo input = do
  validated <- validateAccPlanInputRepo input
  mutation <- liftIO $ createAccPlan (aprPool repo) validated
  planId <- extractMutationId "AccPlan created but id was not returned" mutation
  mPlan <- find repo planId
  case mPlan of
    Just plan -> pure plan
    Nothing -> throwE (NotFound "Created acc plan was not found")

updateAccPlanRepo :: AccPlanRepository -> Int64 -> AccPlanInput -> ExceptT RepositoryError IO AccPlan
updateAccPlanRepo repo planId input = do
  validated <- validateAccPlanInputRepo input
  mutation <- liftIO $ updateAccPlan (aprPool repo) planId validated
  _ <- extractMutationId "AccPlan updated but id was not returned" mutation
  mPlan <- find repo planId
  case mPlan of
    Just plan -> pure plan
    Nothing -> throwE (NotFound "Updated acc plan was not found")

deleteAccPlanRepo :: AccPlanRepository -> Int64 -> ExceptT RepositoryError IO ()
deleteAccPlanRepo repo planId = do
  mutation <- liftIO $ deleteAccPlan (aprPool repo) planId
  case mutation of
    QuerySuccess _ -> pure ()
    QueryError err
      | isNotFoundMessage err -> throwE (NotFound "Acc plan not found")
      | otherwise -> throwE (DatabaseError err)

toAccPlanInput :: AccPlan -> AccPlanInput
toAccPlanInput plan =
  AccPlanInput
    { apiCode = apCode plan,
      apiName = apName plan,
      apiType = apType plan,
      apiParentCode = Nothing,
      apiKind = 0,
      apiIsAnalytical = False
    }

validateAccPlanInputRepo :: AccPlanInput -> ExceptT RepositoryError IO AccPlanInput
validateAccPlanInputRepo input = case Validation.validateAccPlanInput input of
  Right ok -> pure ok
  Left errs ->
    throwE . ValidationError . T.intercalate "; " $ fmap validationMessage errs
  where
    validationMessage (Validation.ValidationError msg) = msg

extractMutationId :: Text -> QueryResult MutationResult -> ExceptT RepositoryError IO Int64
extractMutationId missingIdMessage result = case result of
  QuerySuccess (MutationResult _ (Just rid) _) -> pure rid
  QuerySuccess _ -> throwE (DatabaseError missingIdMessage)
  QueryError err -> throwE (DatabaseError err)

class HasAccPlanRepository a where
  getAccPlanRepository :: a -> AccPlanRepository

instance HasAccPlanRepository AccPlanRepository where
  getAccPlanRepository = id

instance HasRepository AccPlanRepository Pool where
  getRepository = aprPool

mkAccPlanRepository :: Pool -> AccPlanRepository
mkAccPlanRepository = AccPlanRepository

runAccPlanRepository :: AccPlanRepository -> RepositoryT IO a -> IO (Either RepositoryError a)
runAccPlanRepository repo action = runRepository (defaultRepositoryContext (aprPool repo)) action
