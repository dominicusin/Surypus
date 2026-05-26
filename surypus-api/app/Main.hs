{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Exception (finally)
import Data.Time.Clock (secondsToDiffTime)
import Network.Wai.Handler.Warp (run)
import Surypus.API.Server (apiServer)
import Surypus.API.Logger (LogLevel(..), initLogger)
import qualified Surypus.API.Logger as Log
import Hasql.Connection (settings)
import Hasql.Pool (acquire, release)

main :: IO ()
main = do
  logger <- initLogger Info
  Log.logInfo logger "Starting Surypus API server..." []
  
  let connSettings = settings "localhost" 5432 "postgres" "postgres" "surypus"
  pool <- acquire 10 (secondsToDiffTime 30) (secondsToDiffTime 3600) (secondsToDiffTime 600) connSettings
  Log.logInfo logger "Database pool created" []
  
  -- Start server
  let app = apiServer pool logger
  Log.logInfo logger "Server starting on port 3000" []
  run 3000 app `finally` release pool
