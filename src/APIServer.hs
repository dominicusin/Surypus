{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module APIServer
  ( ServerConfig(..)
  , runServer
  , healthStatus
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import GHC.Generics (Generic)
import Network.Wai.Handler.Warp (defaultSettings, setHost, setPort)
import Web.Scotty
import Data.Aeson (ToJSON, FromJSON, Value, object, (.=))
import Data.Int (Int64)

-- ============================================================================
-- CONFIG
-- ============================================================================

data ServerConfig = ServerConfig
  { scHost       :: String
  , scPort       :: Int
  } deriving (Eq, Show)

-- ============================================================================
-- SERVER
-- ============================================================================

runServer :: ServerConfig -> IO ()
runServer cfg = do
    putStrLn $ "Starting server on " ++ scHost cfg ++ ":" ++ show (scPort cfg)
    scotty (scPort cfg) $ do
      get "/" $ do
        html "<h1>Surypus ERP/CRM</h1><p>Version 0.1.0</p>"

      get "/api/v1/health" $ do
        json $ object ["status" .= ("healthy" :: Text), "version" .= ("0.1.0" :: Text)]

      get "/api/v1/persons" $ do
        json $ object ["items" .= ([] :: [Value]), "total" .= (0 :: Int)]

      get "/api/v1/goods" $ do
        json $ object ["items" .= ([] :: [Value]), "total" .= (0 :: Int)]

      get "/api/v1/locations" $ do
        json $ object ["items" .= ([] :: [Value]), "total" .= (0 :: Int)]

      get "/api/v1/bills" $ do
        json $ object ["items" .= ([] :: [Value]), "total" .= (0 :: Int)]

      get "/api/v1/stock" $ do
        json $ object ["items" .= ([] :: [Value]), "total" .= (0 :: Int)]

      post "/api/v1/auth/login" $ do
        json $ object 
          [ "token" .= ("stub-token" :: Text)
          , "userId" .= (1 :: Int64)
          , "role" .= ("admin" :: Text)
          ]

healthStatus :: IO Text
healthStatus = pure "healthy"
