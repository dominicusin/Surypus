{-# LANGUAGE OverloadedStrings #-}

module Main where

import Data.Text (Text)
import System.Environment (lookupEnv)
import System.IO (hFlush, stdout)

main :: IO ()
main = do
  putStrLn "Starting Surypus (minimal build)..."
  hFlush stdout
  apiHost <- lookupEnv "SURYPUS_HOST" >>= return . maybe "0.0.0.0" id
  apiPortS <- lookupEnv "SURYPUS_PORT" >>= return . maybe "8080" id
  putStrLn $ "API server would start on " <> apiHost <> ":" <> apiPortS
  putStrLn "Use 'stack build' with full dependencies to run full server."
