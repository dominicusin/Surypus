{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

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

  create repo plan = createAccPlanRepo repo (toAccPlanInput plan)

  update repo planId plan = updateAccPlanRepo repo planId (toAccPlanInput plan)

  delete = deleteAccPlanRepo

listAccPlansRepo :: AccPlanRepository -> ExceptT RepositoryError IO [AccPlan]
listAccPlansRepo = findAll

createAccPlanRepo :: AccPlanRepository -> AccPlanInput -> ExceptT RepositoryError IO AccPlan
createAccPlanRepo repo input = do
  validated <- validateAccPlanInputRepo input
  mutation <- liftIO $ createAccPlan (aprPool repo) validated
  planId <- extractMutationId "Account plan created but id was not returned" mutation
  mPlan <- find repo planId
  case mPlan of
    Just plan -> pure plan
    Nothing -> throwE (NotFound "Created account plan was not found")

updateAccPlanRepo :: AccPlanRepository -> Int64 -> AccPlanInput -> ExceptT RepositoryError IO AccPlan
updateAccPlanRepo repo planId input = do
  validated <- validateAccPlanInputRepo input
  mutation <- liftIO $ updateAccPlan (aprPool repo) planId validated
  _ <- extractMutationId "Account plan updated but id was not returned" mutation
  mPlan <- find repo planId
  case mPlan of
    Just plan -> pure plan
    Nothing -> throwE (NotFound "Updated account plan was not found")

deleteAccPlanRepo :: AccPlanRepository -> Int64 -> ExceptT RepositoryError IO ()
deleteAccPlanRepo repo planId = do
  mutation <- liftIO $ deleteAccPlan (aprPool repo) planId
  case mutation of
    QuerySuccess _ -> pure ()
    QueryError err
      | isNotFoundMessage err -> throwE (NotFound "Account plan not found")
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
