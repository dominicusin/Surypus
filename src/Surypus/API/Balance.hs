{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE TypeOperators #-}

module Surypus.API.Balance where

import Data.Aeson (FromJSON, ToJSON)
import Data.Int (Int64)
import GHC.Generics (Generic)
import Servant

data BalanceResponse = BalanceResponse
  { accountId :: Int64,
    balance :: Double
  }
  deriving (Show, Eq, Generic)

instance ToJSON BalanceResponse

instance FromJSON BalanceResponse

type BalanceAPI = "balances" :> Capture "accountId" Int64 :> Get '[JSON] BalanceResponse

balanceHandler :: Int64 -> Handler BalanceResponse
balanceHandler accId = pure $ BalanceResponse accId 0.0

-- Expose a Server for this API segment to ease composition in server.hs
balanceServer :: Server BalanceAPI
balanceServer = balanceHandler
