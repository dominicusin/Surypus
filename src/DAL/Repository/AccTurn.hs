{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

module DAL.Repository.AccTurn
  ( AccTurnRepository (..),
    HasAccTurnRepository (..),
    mkAccTurnRepository,
    runAccTurnRepository,
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
import DAL.Repository
import DAL.Types
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)
import Surypus.Types (toDecimal)
import qualified Surypus.Validation as Validation

data AccTurnRepository = AccTurnRepository
  { atrPool :: Pool
  }

instance Repository AccTurnRepository AccTurn where
  find repo turnId = do
    result <- liftIO $ getAccTurnById (atrPool repo) turnId
    case result of
      QuerySuccess turn -> pure (Just turn)
      QueryError err
        | isNotFoundMessage err -> pure Nothing
        | otherwise -> throwE (DatabaseError err)

  findAll repo = do
    result <- liftIO $ getAccTurns (atrPool repo)
    case result of
      QuerySuccess turns -> pure turns
      QueryError err -> throwE (DatabaseError err)

  create repo turn = createAccTurnRepo repo (toAccTurnInput turn)

  update repo turnId turn = updateAccTurnRepo repo turnId (toAccTurnInput turn)

  delete = deleteAccTurnRepo

listAccTurnsRepo :: AccTurnRepository -> ExceptT RepositoryError IO [AccTurn]
listAccTurnsRepo = findAll

createAccTurnRepo :: AccTurnRepository -> AccTurnInput -> ExceptT RepositoryError IO AccTurn
createAccTurnRepo repo input = do
  validated <- validateAccTurnInputRepo input
  mutation <- liftIO $ createAccTurn (atrPool repo) validated
  turnId <- extractMutationId "Accounting entry created but id was not returned" mutation
  mTurn <- find repo turnId
  case mTurn of
    Just turn -> pure turn
    Nothing -> throwE (NotFound "Created accounting entry was not found")

updateAccTurnRepo :: AccTurnRepository -> Int64 -> AccTurnInput -> ExceptT RepositoryError IO AccTurn
updateAccTurnRepo repo turnId input = do
  validated <- validateAccTurnInputRepo input
  mutation <- liftIO $ updateAccTurn (atrPool repo) turnId validated
  _ <- extractMutationId "Accounting entry updated but id was not returned" mutation
  mTurn <- find repo turnId
  case mTurn of
    Just turn -> pure turn
    Nothing -> throwE (NotFound "Updated accounting entry was not found")

deleteAccTurnRepo :: AccTurnRepository -> Int64 -> ExceptT RepositoryError IO ()
deleteAccTurnRepo repo turnId = do
  mutation <- liftIO $ deleteAccTurn (atrPool repo) turnId
  case mutation of
    QuerySuccess _ -> pure ()
    QueryError err
      | isNotFoundMessage err -> throwE (NotFound "Accounting entry not found")
      | otherwise -> throwE (DatabaseError err)

toAccTurnInput :: AccTurn -> AccTurnInput
toAccTurnInput turn =
  AccTurnInput
    { atiDbtAccId = atDbtAccId turn,
      atiCrdAccId = atCrdAccId turn,
      atiAmount = toDecimal (atAmount turn),
      atiDate = atDate turn,
      atiBillId = atBillId turn
    }

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
  getRepository = atrPool

mkAccTurnRepository :: Pool -> AccTurnRepository
mkAccTurnRepository = AccTurnRepository

runAccTurnRepository :: AccTurnRepository -> RepositoryT IO a -> IO (Either RepositoryError a)
runAccTurnRepository repo action = runRepository (defaultRepositoryContext (atrPool repo)) action
