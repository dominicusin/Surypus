#!/usr/bin/env runhaskell

-- |
--  Generate static/swagger.json from Surypus.API.OpenApi.apiSwaggerSpec.
--  Run: ./scripts/gen-swagger-json.hs
module Main where

import Data.Aeson.Encode.Pretty (encodePretty)
import qualified Data.ByteString.Lazy as LBS
import Surypus.API.OpenApi (apiSwaggerSpec)
import System.Directory (createDirectoryIfMissing)

main :: IO ()
main = do
  createDirectoryIfMissing False "static"
  LBS.writeFile "static/swagger.json" (encodePretty apiSwaggerSpec)
  putStrLn "static/swagger.json generated"
