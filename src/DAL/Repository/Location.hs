{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}

module DAL.Repository.Location
  ( LocationRepository (..),
    HasLocationRepository (..),
    mkLocationRepository,
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
import DAL.Repository (HasRepository (..), RepositoryError (..), isNotFoundMessage)
import DAL.Types
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Hasql.Pool (Pool)
import qualified Surypus.Validation as Validation

newtype LocationRepository = LocationRepository
  { lrPool :: Pool
  }

listLocationsRepo :: LocationRepository -> ExceptT RepositoryError IO [Location]
listLocationsRepo repo = do
  result <- liftIO $ getLocations (lrPool repo)
  case result of
    QuerySuccess locations -> pure locations
    QueryError err -> throwE (DatabaseError err)

createLocationRepo :: LocationRepository -> LocationInput -> ExceptT RepositoryError IO Location
createLocationRepo repo input = do
  validated <- validateLocationInputRepo input
  mutation <- liftIO $ createLocation (lrPool repo) validated
  locationId <- extractMutationId "Location created but id was not returned" mutation
  result <- liftIO $ getLocationById (lrPool repo) locationId
  case result of
    QuerySuccess location -> pure location
    QueryError err -> throwE (DatabaseError err)

updateLocationRepo :: LocationRepository -> Int64 -> LocationInput -> ExceptT RepositoryError IO Location
updateLocationRepo repo locationId input = do
  validated <- validateLocationInputRepo input
  mutation <- liftIO $ updateLocation (lrPool repo) locationId validated
  _ <- extractMutationId "Location updated but id was not returned" mutation
  result <- liftIO $ getLocationById (lrPool repo) locationId
  case result of
    QuerySuccess location -> pure location
    QueryError err -> throwE (DatabaseError err)

deleteLocationRepo :: LocationRepository -> Int64 -> ExceptT RepositoryError IO ()
deleteLocationRepo repo locationId = do
  mutation <- liftIO $ deleteLocation (lrPool repo) locationId
  case mutation of
    QuerySuccess _ -> pure ()
    QueryError err
      | isNotFoundMessage err -> throwE (NotFound "Location not found")
      | otherwise -> throwE (DatabaseError err)

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
  getPool = lrPool

mkLocationRepository :: Pool -> LocationRepository
mkLocationRepository = LocationRepository
