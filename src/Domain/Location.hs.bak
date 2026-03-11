{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module Domain.Location
  ( Location(..)
  , LocationFilter(..)
  ) where

import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import Data.Text (Text)
import GHC.Generics (Generic)

data Location = Location
  { locationId      :: Maybe Int64
  , locationCode    :: Maybe Text
  , locationName    :: Text
  , locationType    :: Int
  , locationAddress :: Maybe Text
  , locationStatus  :: Int
  , locationCapacity:: Maybe Double
  , locationParent  :: Maybe Int64
  } deriving (Eq, Show, Generic)

instance FromJSON Location
instance ToJSON Location

data LocationFilter = LocationFilter
  { lfName   :: Maybe Text
  , lfType   :: Maybe Int
  , lfLimit  :: Int
  , lfOffset :: Int
  } deriving (Eq, Show, Generic)

instance FromJSON LocationFilter
instance ToJSON LocationFilter
