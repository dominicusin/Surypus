{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

module DAL.Repository.Person
  ( PersonRepository (..),
    HasPersonRepository (..),
    mkPersonRepository,
    runPersonRepository,
    listPersonsPage,
    searchPersonsRepo,
    createPersonRepo,
    updatePersonRepo,
    deletePersonRepo,
  )
where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.Except (ExceptT, runExceptT, throwE)
import DAL.Mutations (createPerson, deletePerson, updatePerson)
import DAL.Queries (getPersonById, getPersonsPaginated, searchPersons)
import DAL.Repository (HasRepository (..), RepositoryError (..), isNotFoundMessage)
import DAL.Types
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)
import qualified Surypus.Validation as Validation

newtype PersonRepository = PersonRepository
  { prPool :: Pool
  }

runPersonRepository :: PersonRepository -> ExceptT RepositoryError IO a -> IO (Either RepositoryError a)
runPersonRepository = runExceptT

listPersonsPage :: PersonRepository -> PersonFilter -> Maybe PersonSortBy -> Maybe SortDir -> Pagination -> ExceptT RepositoryError IO (PaginatedResult Person)
listPersonsPage repo filter' mSortBy mSortDir pagination = do
  result <- liftIO $ getPersonsPaginated (prPool repo) filter' mSortBy mSortDir pagination
  case result of
    QuerySuccess persons -> pure persons
    QueryError err -> throwE (DatabaseError err)

searchPersonsRepo :: PersonRepository -> Text -> ExceptT RepositoryError IO [Person]
searchPersonsRepo repo query = do
  result <- liftIO $ searchPersons (prPool repo) query
  case result of
    QuerySuccess persons -> pure persons
    QueryError err -> throwE (DatabaseError err)

createPersonRepo :: PersonRepository -> PersonInput -> ExceptT RepositoryError IO Person
createPersonRepo repo input = do
  validated <- validatePersonInputRepo input
  mutation <- liftIO $ createPerson (prPool repo) validated
  pid <- extractMutationId "Person created but id was not returned" mutation
  result <- liftIO $ getPersonById (prPool repo) pid
  case result of
    QuerySuccess person -> pure person
    QueryError err -> throwE (DatabaseError err)

updatePersonRepo :: PersonRepository -> Int64 -> PersonInput -> ExceptT RepositoryError IO Person
updatePersonRepo repo pid input = do
  validated <- validatePersonInputRepo input
  mutation <- liftIO $ updatePerson (prPool repo) pid validated
  _ <- extractMutationId "Person updated but id was not returned" mutation
  result <- liftIO $ getPersonById (prPool repo) pid
  case result of
    QuerySuccess person -> pure person
    QueryError err -> throwE (DatabaseError err)

deletePersonRepo :: PersonRepository -> Int64 -> ExceptT RepositoryError IO ()
deletePersonRepo repo pid = do
  mutation <- liftIO $ deletePerson (prPool repo) pid
  case mutation of
    QuerySuccess _ -> pure ()
    QueryError err
      | isNotFoundMessage err -> throwE (NotFound "Person not found")
      | otherwise -> throwE (DatabaseError err)

validatePersonInputRepo :: PersonInput -> ExceptT RepositoryError IO PersonInput
validatePersonInputRepo input = case Validation.validatePersonInput input of
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

class HasPersonRepository a where
  getPersonRepository :: a -> PersonRepository

instance HasPersonRepository PersonRepository where
  getPersonRepository = id

instance HasRepository PersonRepository Pool where
  getPool = prPool

mkPersonRepository :: Pool -> PersonRepository
mkPersonRepository = PersonRepository
