{-# LANGUAGE OverloadedStrings #-}

module Main where

import APIServer (RateLimitConfig (..), ServerConfig (..), defaultRateLimit, runServer)
import DB.Connection (PoolConfig (..), createPool)
import Data.Text (Text)
import Hasql.Pool (Pool)
import System.Environment (lookupEnv)

main :: IO ()
main = do
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
  pool <- createPool poolCfg

  let config =
        ServerConfig
          { scHost = "0.0.0.0",
            scPort = 8080,
            scLogRequests = False,
            scJwtSecret = ("surypus-secret-key-2026" :: Text),
            scRateLimit = defaultRateLimit,
            scPool = pool
          }

  runServer config
