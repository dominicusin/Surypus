{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

module DAL.Repository.AccTurn
  ( AccTurnRepository (..),
    HasAccTurnRepository (..),
    mkAccTurnRepository,
    listAccTurnsRepo,
    createAccTurnRepo,
    updateAccTurnRepo,
    deleteAccTurnRepo,
  )
where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.Except (ExceptT, throwE)
import DAL.Mutations (createAccTurn, deleteAccTurn, updateAccTurn)
import DAL.Queries (getAccTurnById, getAccTurns)
import DAL.Repository (HasRepository (..), RepositoryError (..), isNotFoundMessage)
import DAL.Types
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)
import qualified Surypus.Validation as Validation

newtype AccTurnRepository = AccTurnRepository
  { atrPool :: Pool
  }

listAccTurnsRepo :: AccTurnRepository -> ExceptT RepositoryError IO [AccTurn]
listAccTurnsRepo repo = do
  result <- liftIO $ getAccTurns (atrPool repo)
  case result of
    QuerySuccess turns -> pure turns
    QueryError err -> throwE (DatabaseError err)

createAccTurnRepo :: AccTurnRepository -> AccTurnInput -> ExceptT RepositoryError IO AccTurn
createAccTurnRepo repo input = do
  validated <- validateAccTurnInputRepo input
  mutation <- liftIO $ createAccTurn (atrPool repo) validated
  turnId <- extractMutationId "Accounting entry created but id was not returned" mutation
  result <- liftIO $ getAccTurnById (atrPool repo) turnId
  case result of
    QuerySuccess turn -> pure turn
    QueryError err -> throwE (DatabaseError err)

updateAccTurnRepo :: AccTurnRepository -> Int64 -> AccTurnInput -> ExceptT RepositoryError IO AccTurn
updateAccTurnRepo repo turnId input = do
  validated <- validateAccTurnInputRepo input
  mutation <- liftIO $ updateAccTurn (atrPool repo) turnId validated
  _ <- extractMutationId "Accounting entry updated but id was not returned" mutation
  result <- liftIO $ getAccTurnById (atrPool repo) turnId
  case result of
    QuerySuccess turn -> pure turn
    QueryError err -> throwE (DatabaseError err)

deleteAccTurnRepo :: AccTurnRepository -> Int64 -> ExceptT RepositoryError IO ()
deleteAccTurnRepo repo turnId = do
  mutation <- liftIO $ deleteAccTurn (atrPool repo) turnId
  case mutation of
    QuerySuccess _ -> pure ()
    QueryError err
      | isNotFoundMessage err -> throwE (NotFound "Accounting entry not found")
      | otherwise -> throwE (DatabaseError err)

validateAccTurnInputRepo :: AccTurnInput -> ExceptT RepositoryError IO AccTurnInput
validateAccTurnInputRepo input = case Validation.validateAccTurnInput input of
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

class HasAccTurnRepository a where
  getAccTurnRepository :: a -> AccTurnRepository

instance HasAccTurnRepository AccTurnRepository where
  getAccTurnRepository = id

instance HasRepository AccTurnRepository Pool where
  getPool = atrPool

mkAccTurnRepository :: Pool -> AccTurnRepository
mkAccTurnRepository = AccTurnRepository
