{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

module DAL.Repository.Location
  ( LocationRepository (..),
    HasLocationRepository (..),
    mkLocationRepository,
    runLocationRepository,
    listLocationsRepo,
    createLocationRepo,
    updateLocationRepo,
    deleteLocationRepo,
  )
where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.Except (ExceptT, throwE)
import DAL.Mutations (createLocation, deleteLocation, updateLocation)
import DAL.Queries (getLocationById, getLocations)
import DAL.Repository
import DAL.Types
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)
import qualified Surypus.Validation as Validation

data LocationRepository = LocationRepository
  { lrPool :: Pool
  }

instance Repository LocationRepository Location where
  find repo locationId = do
    result <- liftIO $ getLocationById (lrPool repo) locationId
    case result of
      QuerySuccess location -> pure (Just location)
      QueryError err
        | isNotFoundMessage err -> pure Nothing
        | otherwise -> throwE (DatabaseError err)

  findAll repo = do
    result <- liftIO $ getLocations (lrPool repo)
    case result of
      QuerySuccess locations -> pure locations
      QueryError err -> throwE (DatabaseError err)

  create repo location = do
    created <- createLocationRepo repo (toLocationInput location)
    pure (lId created)

  update repo locationId location = do
    updated <- updateLocationRepo repo locationId (toLocationInput location)
    pure (Just updated)

  delete repo locationId = do
    deleteLocationRepo repo locationId
    pure Nothing

listLocationsRepo :: LocationRepository -> ExceptT RepositoryError IO [Location]
listLocationsRepo = findAll

createLocationRepo :: LocationRepository -> LocationInput -> ExceptT RepositoryError IO Location
createLocationRepo repo input = do
  validated <- validateLocationInputRepo input
  mutation <- liftIO $ createLocation (lrPool repo) validated
  locationId <- extractMutationId "Location created but id was not returned" mutation
  mLocation <- find repo locationId
  case mLocation of
    Just location -> pure location
    Nothing -> throwE (NotFound "Created location was not found")

updateLocationRepo :: LocationRepository -> Int64 -> LocationInput -> ExceptT RepositoryError IO Location
updateLocationRepo repo locationId input = do
  validated <- validateLocationInputRepo input
  mutation <- liftIO $ updateLocation (lrPool repo) locationId validated
  _ <- extractMutationId "Location updated but id was not returned" mutation
  mLocation <- find repo locationId
  case mLocation of
    Just location -> pure location
    Nothing -> throwE (NotFound "Updated location was not found")

deleteLocationRepo :: LocationRepository -> Int64 -> ExceptT RepositoryError IO ()
deleteLocationRepo repo locationId = do
  mutation <- liftIO $ deleteLocation (lrPool repo) locationId
  case mutation of
    QuerySuccess _ -> pure ()
    QueryError err
      | isNotFoundMessage err -> throwE (NotFound "Location not found")
      | otherwise -> throwE (DatabaseError err)

toLocationInput :: Location -> LocationInput
toLocationInput location =
  LocationInput
    { liCode = lCode location,
      liName = lName location,
      liType = lType location
    }

validateLocationInputRepo :: LocationInput -> ExceptT RepositoryError IO LocationInput
validateLocationInputRepo input = case Validation.validateLocationInput input of
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

class HasLocationRepository a where
  getLocationRepository :: a -> LocationRepository

instance HasLocationRepository LocationRepository where
  getLocationRepository = id

instance HasRepository LocationRepository Pool where
  getRepository = lrPool

mkLocationRepository :: Pool -> LocationRepository
mkLocationRepository = LocationRepository

runLocationRepository :: LocationRepository -> RepositoryT IO a -> IO (Either RepositoryError a)
runLocationRepository repo action = runRepository (defaultRepositoryContext (lrPool repo)) action
