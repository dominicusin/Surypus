{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Exception (finally)
import Data.Time.Clock (secondsToDiffTime)
import Network.Wai.Handler.Warp (run)
import Surypus.API.Server (apiServer)
import Surypus.API.Logger (LogLevel(..), initLogger)
import qualified Surypus.API.Logger as Log
import Database.Persist.Postgresql (createPostgresqlPool)
import Surypus.DAL.ORMPool (ConnectionPool)

main :: IO ()
main = do
    logger <- initLogger Info
    Log.logInfo logger "Starting Surypus API server..." []
    
    pool <- createPostgresqlPool "host=localhost port=5432 user=postgres password=postgres dbname=surypus" 10
    Log.logInfo logger "Database pool created" []
    
    -- Start server
    let app = apiServer pool logger
    Log.logInfo logger "Server starting on port 3000" []
    run 3000 app `finally` return ()
