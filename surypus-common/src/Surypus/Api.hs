{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeOperators #-}

module Surypus.Api
  ( SurypusApi,
    apiProxy,
  )
where

import Data.Int (Int64)
import Data.Text (Text)
import GHC.Generics (Generic)
import Servant
import Surypus.Types.Common (QueryParams (..))

type SurypusApi = "api" :> "v1" :> RawApi

type RawApi = Get '[JSON] Text

apiProxy :: Proxy SurypusApi
apiProxy = Proxy
