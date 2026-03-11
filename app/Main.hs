{-# LANGUAGE OverloadedStrings #-}

module Main where

import Control.Monad (void)
import Data.Maybe (fromMaybe)
import Data.ByteString.Char8 (pack)
import System.Environment (lookupEnv)
import DB.Connection (PoolConfig(..), createPool, closePool, initSchema)
import qualified Core.Auth.JWT as JWT
import APIServer (ServerConfig(..), runServer)

main :: IO ()
main = do
    putStrLn "========================================="
    putStrLn "  Surypus HTTP Server (Scotty)"
    putStrLn "  Version 0.1.0"
    putStrLn "========================================="

    let host = "0.0.0.0"
        port = 8080

        poolCfg = PoolConfig
          { pcHost = "localhost"
          , pcPort = 5432
          , pcUser = "surypus"
          , pcPassword = "surypus"
          , pcDatabase = "surypus"
          , pcConnections = 10
          , pcStripes = 1
          , pcIdleTime = 60
          }

        jwtSecret =
          pack $
            fromMaybe "surypus-development-secret" (lookupEnv "SURYPUS_JWT_SECRET")

        authCfg = JWT.JWTConfig
          { JWT.jwtSecret = jwtSecret
          , JWT.jwtIssuer = "surypus"
          , JWT.jwtTTL = 3600
          }

        serverCfg = ServerConfig
          { scHost = host
          , scPort = port
          , scPoolConfig = poolCfg
          , scAuthConfig = authCfg
          }

    pool <- createPool poolCfg
    initSchema pool
    putStrLn $ "Running API server on http://" ++ host ++ ":" ++ show port
    runServer serverCfg pool
    closePool pool
