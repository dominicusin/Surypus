-- | Location API
module Surypus.API.Location
  ( listLocations,
    createLocation,
    getLocation,
    updateLocation,
    deleteLocation,
  )
where

import qualified DAL.Mutations as M
import qualified DAL.Queries as Q
import DAL.Types
  ( Location (..),
    LocationInput (..),
    MutationResult (..),
    QueryResult (..),
  )
import Data.Int (Int64)
import Hasql.Pool (Pool)

listLocations :: Pool -> IO (QueryResult [Location])
listLocations = Q.getLocations

createLocation :: Pool -> LocationInput -> IO (QueryResult MutationResult)
createLocation = M.createLocation

getLocation :: Pool -> Int64 -> IO (QueryResult Location)
getLocation = Q.getLocationById

updateLocation :: Pool -> Int64 -> LocationInput -> IO (QueryResult MutationResult)
updateLocation = M.updateLocation

deleteLocation :: Pool -> Int64 -> IO (QueryResult MutationResult)
deleteLocation = M.deleteLocation
