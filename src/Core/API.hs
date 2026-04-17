-- | API module - REST API
module Core.API where

import Data.Int (Int64)
import Data.Text (Text)

-- | APIEndpoint - API endpoint
data APIEndpoint = APIEndpoint
  { aeId :: Int64,
    aePath :: Text,
    aeMethod :: HttpMethod,
    aeHandler :: Text,
    aeAuthRequired :: Bool
  }
  deriving (Show, Eq)

data HttpMethod = HM_GET | HM_POST | HM_PUT | HM_DELETE | HM_PATCH
  deriving (Show, Eq)

-- | APILog - API access log
data APILog = APILog
  { alId :: Int64,
    alEndpointId :: Int64,
    alUserId :: Maybe Int64,
    alRequest :: Text, -- JSON
    alResponse :: Text, -- JSON
    alStatus :: Int,
    alTimestamp :: Int64
  }
  deriving (Show, Eq)
