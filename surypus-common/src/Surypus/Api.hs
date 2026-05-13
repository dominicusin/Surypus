{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}

module Surypus.Api
  ( SurypusApi,
    apiProxy,
    AuthenticatedUser (..),
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import GHC.Generics (Generic)
import Servant

-- | Authenticated user context passed to handlers
data AuthenticatedUser = AuthenticatedUser
  { auUserId :: Int64,
    auUsername :: Text,
    auRole :: Text
  }
  deriving (Show, Eq, Generic)

type SurypusApi = "api" :> "v1" :> RawApi

type RawApi = Get '[JSON] Text

apiProxy :: Proxy SurypusApi
apiProxy = Proxy
