{-# LANGUAGE OverloadedStrings #-}
module Main where

import Surypus.RBAC (parsePermissionText)
import Data.Text (Text)
import System.IO (hFlush, stdout)

main :: IO ()
main = do
  putStrLn "Surypus ERP prototype (Phase 1)"
  putStrLn "GHC 9.6.5 | Stack | CI green"
  putStr "Parse test: " >> hFlush stdout
  print (parsePermissionText "person:read" :: Maybe Int)
