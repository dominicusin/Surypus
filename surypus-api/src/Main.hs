{-# LANGUAGE OverloadedStrings #-}

module Main where

import Hasql.Pool (Pool)
import Network.Wai.Handler.Warp (run)
import Surypus.API.Server (apiServer)
import Surypus.JWT (jwtConfigFromSecret)
import Surypus.RBAC.Store (newRBACStore)
import Surypus.API.Logger (initLogger)
import qualified Surypus.API.Logger as Log

main :: IO ()
main = do
  logger <- initLogger
  Log.logInfo logger "MAIN" "Starting Surypus API server..." []
  let jwtCfg = jwtConfigFromSecret "surypus-jwt-secret"
  rbacStore <- newRBACStore $ \_ -> pure ()
  -- Note: In production, pool would be initialized here
  let app = apiServer undefined jwtCfg rbacStore undefined logger
  run 3000 app
