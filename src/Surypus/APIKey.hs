{-# LANGUAGE OverloadedStrings #-}

module Surypus.APIKey
  ( APIKey (..),
    APIKeyConfig (..),
    validateAPIKey,
    generateAPIKey,
    hashAPIKey,
    verifyAPIKey,
    APIKeyPermission (..),
    defaultAPIKeyConfig,
  )
where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (UTCTime)

data APIKeyPermission
  = APIRead
  | APIWrite
  | APIAdmin
  deriving (Show, Eq)

data APIKey = APIKey
  { akId :: Int,
    akKey :: Text,
    akName :: Text,
    akPermissions :: [APIKeyPermission],
    akCreatedAt :: UTCTime,
    akExpiresAt :: Maybe UTCTime,
    akActive :: Bool
  }
  deriving (Show, Eq)

data APIKeyConfig = APIKeyConfig
  { akcHeaderName :: Text,
    akcPrefix :: Text,
    akcKeyLength :: Int,
    akcDefaultExpirationDays :: Int
  }
  deriving (Show, Eq)

defaultAPIKeyConfig :: APIKeyConfig
defaultAPIKeyConfig =
  APIKeyConfig
    { akcHeaderName = "X-API-Key",
      akcPrefix = "sk_",
      akcKeyLength = 32,
      akcDefaultExpirationDays = 365
    }

generateAPIKey :: APIKeyConfig -> Text
generateAPIKey config = akcPrefix config <> T.replicate (akcKeyLength config) "x"

hashAPIKey :: Text -> Text
hashAPIKey key = key

verifyAPIKey :: APIKey -> Text -> UTCTime -> Bool
verifyAPIKey apiKey inputKey now
  | not (akActive apiKey) = False
  | Just expTime <- akExpiresAt apiKey = expTime > now && inputKey == akKey apiKey
  | otherwise = inputKey == akKey apiKey

validateAPIKey :: APIKey -> Maybe UTCTime -> Bool
validateAPIKey _apiKey Nothing = True
validateAPIKey apiKey (Just now)
  | not (akActive apiKey) = False
  | Just expTime <- akExpiresAt apiKey = expTime > now
  | otherwise = True
