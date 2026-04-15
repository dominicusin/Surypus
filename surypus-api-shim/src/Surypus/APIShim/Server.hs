module Surypus.APIShim.Server (apiServerShim, startServantServerShim) where

import Hasql.Pool (Pool)
import Network.Wai (Application)
import Surypus.API.Server (apiServer, startServantServer)
import Surypus.JWT (JWTConfig (..))
import Surypus.RBAC.Store (RBACStore)

-- Lightweight shim: simply delegate to the existing API server entrypoints
apiServerShim :: Pool -> JWTConfig -> RBACStore -> Application
apiServerShim = apiServer

startServantServerShim :: Int -> Pool -> JWTConfig -> RBACStore -> IO ()
startServantServerShim port pool cfg store = do
  -- Call into the actual server; ignore the returned Application, since real function returns IO () in some variants
  startServantServer port pool cfg store
