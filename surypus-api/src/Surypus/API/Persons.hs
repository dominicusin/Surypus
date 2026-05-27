{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE OverloadedStrings #-}

module Surypus.API.Persons (
    listPersons,
    createPerson,
    getPerson,
    updatePerson,
    deletePerson,
    searchPersons,
)
where

import DAL.Database (Pool)
import qualified DAL.Mutations as Mut
import DAL.Queries (getPersonById, getPersons)
import qualified DAL.Queries as Queries
import DAL.Types (MutationResult (..), Person (..), PersonInput (..), QueryResult (..))
import Data.Int (Int64)
import qualified Data.Text as T

-- | List persons using DAL.Queries
listPersons :: Pool -> Maybe String -> Maybe String -> Maybe Int -> Maybe Int -> Maybe Int -> IO (QueryResult [Person])
listPersons pool _limit _offset _status _type _search = do
    getPersons pool

-- | Create a new person using DAL.Mutations
createPerson :: Pool -> PersonInput -> IO (QueryResult MutationResult)
createPerson = Mut.createPerson

-- | Get a specific person by ID using DAL.Queries
getPerson :: Pool -> Int64 -> IO (QueryResult Person)
getPerson pool pid = getPersonById pool pid

-- | Update a person using DAL.Mutations
updatePerson :: Pool -> Int64 -> PersonInput -> IO (QueryResult MutationResult)
updatePerson pool pid input = Mut.updatePerson pool pid input

-- | Delete a person using DAL.Mutations
deletePerson :: Pool -> Int64 -> IO (QueryResult ())
deletePerson pool pid = do
    result <- Mut.deletePerson pool pid
    case result of
        QuerySuccess _ -> return $ QuerySuccess ()
        QueryError err -> return $ QueryError err

-- | Search persons using DAL.Queries
searchPersons :: Pool -> String -> IO (QueryResult [Person])
searchPersons pool query = Queries.searchPersons pool (T.pack query)
