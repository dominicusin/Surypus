{-# LANGUAGE OverloadedStrings #-}

module Main where

import Network.Wai.Handler.Warp (run)
import Network.Wai.Middleware.Gzip (gzip, def)
import Network.Wai.Middleware.RequestLogger (logStdoutDev)
import Surypus.API.Server (apiServer)
import Surypus.API.Logger (initLogger, LogLevel(Info))
import DAL.ORMPool (createPool)
import System.Environment (lookupEnv)
import System.IO (hFlush, stdout)

main :: IO ()
main = do
  pool <- createPool
  logger <- initLogger Info
  app <- apiServer pool logger
  port <- fmap (maybe 8080 read) (lookupEnv "PORT")
  putStrLn $ "Starting Surypus server on http://0.0.0.0:" ++ show port
  hFlush stdout
  run port $ logStdoutDev $ gzip def app
