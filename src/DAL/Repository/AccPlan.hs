{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

module DAL.Repository.AccPlan
  ( AccPlanRepository (..),
    HasAccPlanRepository (..),
    mkAccPlanRepository,
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
import DAL.Repository (HasRepository (..), RepositoryError (..), isNotFoundMessage)
import DAL.Types
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)
import qualified Surypus.Validation as Validation

newtype AccPlanRepository = AccPlanRepository
  { aprPool :: Pool
  }

listAccPlansRepo :: AccPlanRepository -> ExceptT RepositoryError IO [AccPlan]
listAccPlansRepo repo = do
  result <- liftIO $ getAccPlans (aprPool repo)
  case result of
    QuerySuccess plans -> pure plans
    QueryError err -> throwE (DatabaseError err)

createAccPlanRepo :: AccPlanRepository -> AccPlanInput -> ExceptT RepositoryError IO AccPlan
createAccPlanRepo repo input = do
  validated <- validateAccPlanInputRepo input
  mutation <- liftIO $ createAccPlan (aprPool repo) validated
  planId <- extractMutationId "AccPlan created but id was not returned" mutation
  result <- liftIO $ getAccPlanById (aprPool repo) planId
  case result of
    QuerySuccess plan -> pure plan
    QueryError err -> throwE (DatabaseError err)

updateAccPlanRepo :: AccPlanRepository -> Int64 -> AccPlanInput -> ExceptT RepositoryError IO AccPlan
updateAccPlanRepo repo planId input = do
  validated <- validateAccPlanInputRepo input
  mutation <- liftIO $ updateAccPlan (aprPool repo) planId validated
  _ <- extractMutationId "AccPlan updated but id was not returned" mutation
  result <- liftIO $ getAccPlanById (aprPool repo) planId
  case result of
    QuerySuccess plan -> pure plan
    QueryError err -> throwE (DatabaseError err)

deleteAccPlanRepo :: AccPlanRepository -> Int64 -> ExceptT RepositoryError IO ()
deleteAccPlanRepo repo planId = do
  mutation <- liftIO $ deleteAccPlan (aprPool repo) planId
  case mutation of
    QuerySuccess _ -> pure ()
    QueryError err
      | isNotFoundMessage err -> throwE (NotFound "Acc plan not found")
      | otherwise -> throwE (DatabaseError err)

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
  getPool = aprPool

mkAccPlanRepository :: Pool -> AccPlanRepository
mkAccPlanRepository = AccPlanRepository
