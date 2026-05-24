module Surypus.APIShim.Server
  ( apiServerShim,
    startServantServerShim,
    apiServerShim_V2,
    startServantServerShim_V2,
    newRBACShim,
    RBACShim (..),
  )
where

import DAL.Database (Pool)
import Network.Wai (Application)
import Surypus.API.Server (apiServer, startServantServer)
import Surypus.JWT (JWTConfig (..))
import Surypus.Metrics (Metrics)
import Surypus.RBAC.Store (RBACStore)

-- Lightweight wrapper around the real RBAC store to enable shim migrations
data RBACShim = RBACShim {unRBACShim :: RBACStore}

-- Simple bridging: old API shim uses RBACStore directly
apiServerShim :: Pool -> JWTConfig -> RBACStore -> Metrics -> Application
apiServerShim = apiServer

startServantServerShim :: Int -> Pool -> JWTConfig -> RBACStore -> Metrics -> IO ()
startServantServerShim port pool cfg store metrics = do
  startServantServer port pool cfg store metrics

-- New API-V2 bridging wrappers
apiServerShim_V2 :: Pool -> JWTConfig -> RBACShim -> Metrics -> Application
apiServerShim_V2 pool cfg (RBACShim s) metrics = apiServerShim pool cfg s metrics

startServantServerShim_V2 :: Int -> Pool -> JWTConfig -> RBACShim -> Metrics -> IO ()
startServantServerShim_V2 port pool cfg shim metrics = startServantServerShim port pool cfg (unRBACShim shim) metrics

newRBACShim :: RBACStore -> RBACShim
newRBACShim = RBACShim
