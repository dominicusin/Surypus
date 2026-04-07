-- | Persons (Clients/Customers) API
--
-- This module provides the persons (clients/customers) API functionality
-- for the ERP system.
module Surypus.API.Persons
  ( listPersons,
    createPerson,
    getPerson,
    updatePerson,
    deletePerson,
    searchPersons,
  )
where

import qualified DAL.Mutations as M
import qualified DAL.Queries as Q
import DAL.Types
  ( MutationResult (..),
    PaginatedResult (..),
    Pagination (..),
    Person (..),
    PersonFilter (..),
    PersonInput (..),
    QueryResult (..),
  )
import Data.Int (Int64)
import Data.Maybe (fromMaybe)
import Data.Text (Text)
import Hasql.Pool (Pool)

listPersons :: Pool -> Maybe Text -> Maybe Text -> Maybe Int -> Maybe Int -> Maybe Int -> IO (QueryResult [Person])
listPersons pool mName mInn mType mStatus mLimit = do
  let filter' =
        PersonFilter
          { pfName = mName,
            pfINN = mInn,
            pfPersonType = mType,
            pfStatus = mStatus
          }
      pagination =
        Pagination
          { pgLimit = fromMaybe 50 mLimit,
            pgOffset = 0
          }
  result <- Q.getPersonsPaginated pool filter' Nothing Nothing pagination
  case result of
    QuerySuccess (PaginatedResult persons _ _ _) -> pure (QuerySuccess persons)
    QueryError err -> pure (QueryError err)

createPerson :: Pool -> PersonInput -> IO (QueryResult MutationResult)
createPerson = M.createPerson

getPerson :: Pool -> Int64 -> IO (QueryResult Person)
getPerson = Q.getPersonById

updatePerson :: Pool -> Int64 -> PersonInput -> IO (QueryResult MutationResult)
updatePerson = M.updatePerson

deletePerson :: Pool -> Int64 -> IO (QueryResult MutationResult)
deletePerson = M.deletePerson

searchPersons :: Pool -> Text -> IO (QueryResult [Person])
searchPersons = Q.searchPersons
