{-# LANGUAGE OverloadedStrings #-}

module Main where

import APIServer (ServerConfig (..), defaultRateLimit, runServer)
import DB.Connection (PoolConfig (..), createPool)
import Data.Text (Text)
import System.Environment (lookupEnv)
import System.IO (hFlush, stdout)

main :: IO ()
main = do
  putStrLn "Starting Surypus..."
  hFlush stdout
  host <- lookupEnv "DB_HOST" >>= return . maybe "localhost" id
  portS <- lookupEnv "DB_PORT" >>= return . maybe "5432" id
  user <- lookupEnv "DB_USER" >>= return . maybe "surypus" id
  password <- lookupEnv "DB_PASSWORD" >>= return . maybe "surypus" id
  database <- lookupEnv "DB_NAME" >>= return . maybe "surypus" id

  let poolCfg =
        PoolConfig
          { pcHost = host,
            pcPort = read portS,
            pcUser = user,
            pcPassword = password,
            pcDatabase = database,
            pcConnections = 10
          }
  putStrLn "Creating pool..."
  hFlush stdout
  pool <- createPool poolCfg
  putStrLn "Pool created successfully."
  hFlush stdout

  rateLimitConfig <- defaultRateLimit

  let config =
        ServerConfig
          { scHost = "0.0.0.0",
            scPort = 8080,
            scLogRequests = False,
            scJwtSecret = ("surypus-secret-key-2026" :: Text),
            scRateLimit = rateLimitConfig,
            scPool = pool
          }

  putStrLn "Starting server on port 8080..."
  hFlush stdout
  runServer config
  putStrLn "Server stopped."
