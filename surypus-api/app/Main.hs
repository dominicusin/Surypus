{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Exception (finally)
import Network.Wai.Handler.Warp (run)
import DAL.ORMPool (createPool, closePool)
import Surypus.API.Server (apiServer)
import Surypus.API.Logger (LogLevel(..), initLogger)
import qualified Surypus.API.Logger as Log

main :: IO ()
main = do
    logger <- initLogger Info
    Log.logInfo logger "Starting Surypus API server..." []

    connPool <- createPool
    Log.logInfo logger "Persistent database pool created" []

    let app = apiServer connPool logger
    Log.logInfo logger "Server starting on port 3000" []
    run 3000 app `finally` closePool connPool
