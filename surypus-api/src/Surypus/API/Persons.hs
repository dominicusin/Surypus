{#- LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Persons
  ( listPersons,
    createPerson,
    getPerson,
    updatePerson,
    deletePerson,
    searchPersons,
  )
where

import DAL.Types (Person (..), PersonInput (..), QueryResult (..))
import DAL.Database (Pool)
import DAL.Queries (getPersons, getPersonById, searchPersons as searchPersonsDB)
import qualified DAL.Mutations as Mut
import Data.Int (Int64)
import qualified Data.Text as T

-- | List persons using DAL.Queries
listPersons :: Pool -> Maybe String -> Maybe String -> Maybe Int -> Maybe Int -> Maybe Int -> IO (QueryResult [Person])
listPersons pool _limit _offset _status _type _search = do
  getPersons pool

-- | Create a new person using DAL.Mutations
createPerson :: Pool -> PersonInput -> IO (QueryResult Person)
createPerson pool input = do
  result <- Mut.createPerson pool input
  case result of
    QuerySuccess _ -> getPersons pool
    QueryError err -> return $ QueryError err

-- | Get a specific person by ID using DAL.Queries
getPerson :: Pool -> Int64 -> IO (QueryResult Person)
getPerson pool pid = getPersonById pool pid

-- | Update a person using DAL.Mutations
updatePerson :: Pool -> Int64 -> PersonInput -> IO (QueryResult Person)
updatePerson pool pid input = do
  result <- Mut.updatePerson pool pid input
  case result of
    QuerySuccess _ -> getPersonById pool pid
    QueryError err -> return $ QueryError err

-- | Delete a person using DAL.Mutations
deletePerson :: Pool -> Int64 -> IO (QueryResult ())
deletePerson pool pid = do
  result <- Mut.deletePerson pool pid
  case result of
    QuerySuccess _ -> return $ QuerySuccess ()
    QueryError err -> return $ QueryError err

-- | Search persons using DAL.Queries
searchPersons :: Pool -> String -> IO (QueryResult [Person])
searchPersons pool query = searchPersonsDB pool (T.pack query)