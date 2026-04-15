{-# LANGUAGE OverloadedStrings #-}

module Main where

import Hasql.Pool (Pool)
import Network.Wai.Handler.Warp (run)
import Surypus.API.Server (apiServer)
import Surypus.JWT (jwtConfigFromSecret)
import Surypus.RBAC.Store (newRBACStore)

main :: IO ()
main = do
  putStrLn "Starting Surypus API server..."
  let jwtCfg = jwtConfigFromSecret "surypus-jwt-secret"
  rbacStore <- newRBACStore $ \_ -> pure ()
  let app = apiServer undefined jwtCfg rbacStore
  run 3000 app
