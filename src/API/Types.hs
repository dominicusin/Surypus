{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE TypeOperators #-}

module API.Types where
  ( module API.Types,
    module Servant.API,
  )
where

import Data.Aeson (FromJSON, ToJSON)
import Data.Text (Text)
import qualified Data.Text as T
import Data.Time (Day, UTCTime)
import GHC.Generics (Generic)
import Servant.API
import Surypus.Types (AppError)

data PersonAPI

data PersonInput = PersonInput
  { piName :: Text,
    piINN :: Maybe Text,
    piKPP :: Maybe Text,
    piPersonType :: Int,
    piStatus :: Int
  }
  deriving (Show, Eq, Generic)

instance FromJSON PersonInput

instance ToJSON PersonInput

data PersonResponse = PersonResponse
  { prId :: Int,
    prName :: Text,
    prINN :: Maybe Text,
    prKPP :: Maybe Text,
    prPersonType :: Int,
    prStatus :: Int
  }
  deriving (Show, Eq, Generic)

instance FromJSON PersonResponse

instance ToJSON PersonResponse

data PaginationParams = PaginationParams
  { ppLimit :: Int,
    ppOffset :: Int
  }
  deriving (Show, Eq, Generic)

instance FromJSON PaginationParams

instance ToJSON PaginationParams

data PageResponse a = PageResponse
  { pageItems :: [a],
    pageTotal :: Int,
    pageLimit :: Int,
    pageOffset :: Int
  }
  deriving (Show, Eq, Generic)

instance (ToJSON a) => ToJSON (PageResponse a)

instance (FromJSON a) => FromJSON (PageResponse a)

data ErrorResponse = ErrorResponse
  { errCode :: Int,
    errMessage :: Text,
    errDetails :: Maybe Text
  }
  deriving (Show, Eq, Generic)

instance ToJSON ErrorResponse

mkErrorResponse :: Int -> Text -> ErrorResponse
mkErrorResponse code msg = ErrorResponse code msg Nothing

mkErrorResponseWithDetails :: Int -> Text -> Text -> ErrorResponse
mkErrorResponseWithDetails code msg details = ErrorResponse code msg (Just details)

err400 :: Text -> ErrorResponse
err400 = mkErrorResponse 400

err404 :: Text -> ErrorResponse
err404 = mkErrorResponse 404

err409 :: Text -> ErrorResponse

mkErrorResponseWithDetails' = mkErrorResponseWithDetails

data LoginRequest = LoginRequest
  { lrUsername :: Text,
    lrPassword :: Text
  }
  deriving (Show, Eq, Generic)

instance FromJSON LoginRequest

data LoginResponse = LoginResponse
  { lAccessToken :: Text,
    lRefreshToken :: Text,
    lExpiresAt :: UTCTime,
    lUserId :: Int,
    lUsername :: Text,
    lRole :: Text
  }
  deriving (Show, Eq, Generic)

instance ToJSON LoginResponse

newtype RefreshRequest = RefreshRequest
  { rrRefreshToken :: Text
  }
  deriving (Show, Eq, Generic)

instance FromJSON RefreshRequest

data RefreshResponse = RefreshResponse
  { rfAccessToken :: Text,
    rfExpiresAt :: UTCTime
  }
  deriving (Show, Eq, Generic)

instance ToJSON RefreshResponse

type PersonsAPI =
  "persons" :> Get '[JSON] (PageResponse PersonResponse)
    :<|> "persons" :> ReqBody '[JSON] PersonInput :> Post '[JSON] PersonResponse
    :<|> "persons" :> Capture "id" Int :> Get '[JSON] PersonResponse
    :<|> "persons" :> Capture "id" Int :> ReqBody '[JSON] PersonInput :> Put '[JSON] PersonResponse
    :<|> "persons" :> Capture "id" Int :> Delete '[JSON] ()
    :<|> "persons" :> "search" :> QueryParam "q" Text :> Get '[JSON] (PageResponse PersonResponse)

type AuthAPI =
  "auth" :> "login" :> ReqBody '[JSON] LoginRequest :> Post '[JSON] LoginResponse
    :<|> "auth" :> "refresh" :> ReqBody '[JSON] RefreshRequest :> Post '[JSON] RefreshResponse
    :<|> "auth" :> "logout" :> Header "Authorization" Text :> Post '[JSON] ()

type HealthAPI =
  "health" :> Get '[JSON] (Either ErrorResponse Text)
    :<|> "health" :> "db" :> Get '[JSON] (Either ErrorResponse Text)

type APIv1 =
  "api" :> "v1" :> (AuthAPI :<|> PersonsAPI :<|> HealthAPI)

type API =
  APIv1
    :<|> "swagger.json" :> Get '[JSON] Text
