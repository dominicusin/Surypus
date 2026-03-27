{-# LANGUAGE OverloadedStrings #-}

module Main where

import APIServer (ServerConfig (..), defaultRateLimit, runServer)
import Control.Concurrent (forkIO)
import DB.Connection (createPool, poolConfigFromEnv)
import Data.Text (Text)
import Surypus.WebSocket (newWebSocketHub, runWebSocketServer)
import System.Environment (lookupEnv)
import System.IO (hFlush, stdout)

main :: IO ()
main = do
  putStrLn "Starting Surypus..."
  hFlush stdout
  apiHost <- lookupEnv "SURYPUS_HOST" >>= return . maybe "0.0.0.0" id
  apiPortS <- lookupEnv "SURYPUS_PORT" >>= return . maybe "8080" id
  wsPortS <- lookupEnv "WS_PORT" >>= return . maybe "9160" id

  poolCfg <- poolConfigFromEnv
  putStrLn "Creating pool..."
  hFlush stdout
  pool <- createPool poolCfg
  putStrLn "Pool created successfully."
  hFlush stdout

  wsHub <- newWebSocketHub
  _ <- forkIO $ runWebSocketServer (read wsPortS) wsHub
  putStrLn $ "WebSocket server started on port " <> wsPortS
  hFlush stdout

  rateLimitConfig <- defaultRateLimit

  let config =
        ServerConfig
          { scHost = apiHost,
            scPort = read apiPortS,
            scLogRequests = False,
            scJwtSecret = ("surypus-secret-key-2026" :: Text),
            scRateLimit = rateLimitConfig,
            scPool = pool,
            scWebSocketHub = Just wsHub
          }

  putStrLn $ "Starting server on port " <> apiPortS <> "..."
  hFlush stdout
  runServer config
  putStrLn "Server stopped."
