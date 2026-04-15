module Surypus.APIShim.Server
  ( apiServerShim,
    startServantServerShim,
    apiServerShim_V2,
    startServantServerShim_V2,
    newRBACShim,
    RBACShim (..),
  )
where

import Hasql.Pool (Pool)
import Network.Wai (Application)
import Surypus.API.Server (apiServer, startServantServer)
import Surypus.JWT (JWTConfig (..))
import Surypus.RBAC.Store (RBACStore)

-- Lightweight wrapper around the real RBAC store to enable shim migrations
data RBACShim = RBACShim {unRBACShim :: RBACStore}

-- Simple bridging: old API shim uses RBACStore directly
apiServerShim :: Pool -> JWTConfig -> RBACStore -> Application
apiServerShim = apiServer

startServantServerShim :: Int -> Pool -> JWTConfig -> RBACStore -> IO ()
startServantServerShim port pool cfg store = do
  startServantServer port pool cfg store

-- New API-V2 bridging wrappers
apiServerShim_V2 :: Pool -> JWTConfig -> RBACShim -> Application
apiServerShim_V2 pool cfg (RBACShim s) = apiServerShim pool cfg s

startServantServerShim_V2 :: Int -> Pool -> JWTConfig -> RBACShim -> IO ()
startServantServerShim_V2 port pool cfg shim = startServantServerShim port pool cfg (unRBACShim shim)

newRBACShim :: RBACStore -> RBACShim
newRBACShim = RBACShim
