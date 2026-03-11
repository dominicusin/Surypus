{-# LANGUAGE OverloadedStrings #-}

module Main where

import APIServer (ServerConfig(..), runServer)

main :: IO ()
main = do
    putStrLn "========================================="
    putStrLn "  Surypus HTTP Server"
    putStrLn "  Version 0.1.0"
    putStrLn "========================================="
    
    let config = ServerConfig
          { scPort = 8080
          , scHost = "0.0.0.0"
          , scLogRequests = False
          , scJwtSecret = "surypus-secret-key-2026"
          }
    
    runServer config