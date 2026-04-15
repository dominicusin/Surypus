{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE TypeOperators #-}

module Surypus.API.BalanceREST where

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

-- Simple REST endpoint placeholder: balance for an account.
-- In MVP we return 0.0 until read-models are wired.
balanceHandler :: Int64 -> Handler BalanceResponse
balanceHandler accId = pure $ BalanceResponse accId 0.0

type BalanceRESTAPI = "balances" :> Capture "accountId" Int64 :> Get '[JSON] BalanceResponse
