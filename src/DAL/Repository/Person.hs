{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Person repository interface and implementation.
--
-- This module defines the repository pattern for Person entities, providing
-- CRUD operations and query functions. It abstracts the database access
-- layer and allows for easy mocking in tests.
--
-- The repository is parameterized over a pool type, allowing different
-- connection pool implementations to be used.
--
-- === Examples
--
-- Creating a repository and finding a person:
-- @
-- import DAL.Repository.Person (PersonRepository, mkPersonRepository, runPersonRepository)
-- import DAL.Types (Person)
-- import Hasql.Pool (Pool)
--
-- -- Assuming you have a connection pool
-- let pool :: Pool = undefined -- TODO: Initialize pool
-- let repo :: PersonRepository = mkPersonRepository pool
--
-- -- Find a person by ID
-- result <- runPersonRepository repo $ find 123
-- case result of
--   Right (Just person) -> print (person :: Person)
--   Right Nothing  -> putStrLn "Person not found"
--   Left err       -> putStrLn $ "Error: " ++ err
-- @
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
import Control.Monad.Trans.Except (ExceptT, throwE)
import DAL.Mutations (createPerson, deletePerson, updatePerson)
import DAL.Queries (getPersonById, getPersons, getPersonsPaginated, searchPersons)
import DAL.Repository
import DAL.Types
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)
import qualified Surypus.Validation as Validation

newtype PersonRepository = PersonRepository
  { prPool :: Pool
  }

instance Repository PersonRepository Person where
  find repo pid = do
    result <- liftIO $ getPersonById (prPool repo) pid
    case result of
      QuerySuccess person -> pure (Just person)
      QueryError err
        | isNotFoundMessage err -> pure Nothing
        | otherwise -> throwE (DatabaseError err)

  findAll repo = do
    result <- liftIO $ getPersons (prPool repo)
    case result of
      QuerySuccess persons -> pure persons
      QueryError err -> throwE (DatabaseError err)

  create repo person = do
    created <- createPersonRepo repo (toPersonInput person)
    pure (pId created)

  update repo pid person = do
    updated <- updatePersonRepo repo pid (toPersonInput person)
    pure (Just updated)

  delete repo pid = do
    deletePersonRepo repo pid
    pure Nothing

listPersonsPage :: PersonRepository -> PersonFilter -> Pagination -> Maybe PersonSortBy -> Maybe SortDir -> ExceptT RepositoryError IO (PaginatedResult Person)
listPersonsPage repo personFilter pagination sortBy sortDir = do
  result <- liftIO $ getPersonsPaginated (prPool repo) personFilter sortBy sortDir pagination
  case result of
    QuerySuccess page -> pure page
    QueryError err -> throwE (DatabaseError err)

searchPersonsRepo :: PersonRepository -> Text -> ExceptT RepositoryError IO [Person]
searchPersonsRepo repo queryText = do
  result <- liftIO $ searchPersons (prPool repo) queryText
  case result of
    QuerySuccess persons -> pure persons
    QueryError err -> throwE (DatabaseError err)

createPersonRepo :: PersonRepository -> PersonInput -> ExceptT RepositoryError IO Person
createPersonRepo repo input = do
  validated <- validatePersonInputRepo input
  mutation <- liftIO $ createPerson (prPool repo) validated
  personId <- extractMutationId "Person created but id was not returned" mutation
  mPerson <- find repo personId
  case mPerson of
    Just person -> pure person
    Nothing -> throwE (NotFound "Created person was not found")

updatePersonRepo :: PersonRepository -> Int64 -> PersonInput -> ExceptT RepositoryError IO Person
updatePersonRepo repo personId input = do
  validated <- validatePersonInputRepo input
  mutation <- liftIO $ updatePerson (prPool repo) personId validated
  _ <- extractMutationId "Person updated but id was not returned" mutation
  mPerson <- find repo personId
  case mPerson of
    Just person -> pure person
    Nothing -> throwE (NotFound "Updated person was not found")

deletePersonRepo :: PersonRepository -> Int64 -> ExceptT RepositoryError IO ()
deletePersonRepo repo personId = do
  mutation <- liftIO $ deletePerson (prPool repo) personId
  case mutation of
    QuerySuccess _ -> pure ()
    QueryError err
      | isNotFoundMessage err -> throwE (NotFound "Person not found")
      | otherwise -> throwE (DatabaseError err)

toPersonInput :: Person -> PersonInput
toPersonInput person =
  PersonInput
    { piCode = pCode person,
      piName = pName person,
      piINN = pINN person,
      piKPP = pKPP person,
      piPersonType = pPersonType person,
      piStatus = pStatus person
    }

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
  getRepository = prPool

mkPersonRepository :: Pool -> PersonRepository
mkPersonRepository = PersonRepository

runPersonRepository :: PersonRepository -> RepositoryT IO a -> IO (Either RepositoryError a)
runPersonRepository repo = runRepository (defaultRepositoryContext (prPool repo))
