{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Exception (finally)
import Data.ByteString.Char8 (pack)
import Data.Time.Clock (secondsToDiffTime)
import Network.Wai.Handler.Warp (run)
import Surypus (acquirePool, settings)
import Surypus.API.Server (apiServer)
import Surypus.API.Logger (LogLevel(..), initLogger)
import qualified Surypus.API.Logger as Log

main :: IO ()
main = do
    logger <- initLogger Info
    Log.logInfo logger "Starting Surypus API server..." []

    let timeout = secondsToDiffTime 10
    pool <- acquirePool 10 timeout timeout timeout (settings (pack "localhost") 5432 (pack "postgres") (pack "postgres") (pack "surypus"))
    Log.logInfo logger "Database pool created" []

    let app = apiServer pool logger
    Log.logInfo logger "Server starting on port 3000" []
    run 3000 app `finally` return ()