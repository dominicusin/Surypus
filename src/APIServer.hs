{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE OverloadedStrings #-}

module APIServer
  ( ServerConfig(..)
  , runServer
  , healthStatus
  ) where

import Control.Monad (when)
import Control.Monad.IO.Class (liftIO)
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
  , scLogRequests :: Bool
  } deriving (Eq, Show)

-- ============================================================================
-- AUTH TYPES
-- ============================================================================

data LoginRequest = LoginRequest
  { lrUsername :: Text
  , lrPassword :: Text
  } deriving (Show, Generic)

instance FromJSON LoginRequest

data LoginResponse = LoginResponse
  { token :: Text
  , userId :: Int64
  , role :: Text
  , expiresAt :: Text
  } deriving (Show, Generic)

instance ToJSON LoginResponse

-- ============================================================================
-- SERVER
-- ============================================================================

runServer :: ServerConfig -> IO ()
runServer cfg = do
    putStrLn $ "========================================="
    putStrLn $ "  Surypus HTTP Server v0.1.0"
    putStrLn $ "  Host: " ++ scHost cfg ++ ":" ++ show (scPort cfg)
    putStrLn $ "========================================="
    
    let port = scPort cfg
    
    scotty port $ do
      -- Root
      get "/" $ html "<h1>Surypus ERP/CRM v0.1.0</h1>"

      -- Health
      get "/api/v1/health" $ json $ object 
        [ "status" .= ("healthy" :: Text)
        , "version" .= ("0.1.0" :: Text)
        , "uptime" .= (100 :: Int)
        ]

      -- Auth
      post "/api/v1/auth/login" $ do
        json $ LoginResponse "demo-token" 1 "admin" "2026-12-31T23:59:59Z"

      post "/api/v1/auth/logout" $ json $ object ["success" .= True]

      -- Persons
      get "/api/v1/persons" $ json $ object 
        [ "items" .= ([] :: [Value])
        , "total" .= (0 :: Int)
        ]
      get "/api/v1/persons/:id" $ json $ object ["id" .= (1 :: Int64)]
      post "/api/v1/persons" $ json $ object ["id" .= (1 :: Int64)]
      put "/api/v1/persons/:id" $ json $ object ["updated" .= True]
      delete "/api/v1/persons/:id" $ json $ object ["deleted" .= True]

      -- Goods
      get "/api/v1/goods" $ json $ object ["items" .= ([] :: [Value]), "total" .= (0 :: Int)]
      get "/api/v1/goods/:id" $ json $ object ["id" .= (1 :: Int64)]
      post "/api/v1/goods" $ json $ object ["id" .= (1 :: Int64)]
      put "/api/v1/goods/:id" $ json $ object ["updated" .= True]
      delete "/api/v1/goods/:id" $ json $ object ["deleted" .= True]

      -- Locations
      get "/api/v1/locations" $ json $ object ["items" .= ([] :: [Value]), "total" .= (0 :: Int)]
      get "/api/v1/locations/:id" $ json $ object ["id" .= (1 :: Int64)]
      post "/api/v1/locations" $ json $ object ["id" .= (1 :: Int64)]

      -- Bills
      get "/api/v1/bills" $ json $ object ["items" .= ([] :: [Value]), "total" .= (0 :: Int)]
      get "/api/v1/bills/:id" $ json $ object ["id" .= (1 :: Int64)]
      post "/api/v1/bills" $ json $ object ["id" .= (1 :: Int64)]

      -- Stock
      get "/api/v1/stock" $ json $ object ["items" .= ([] :: [Value])]
      get "/api/v1/stock/:gid/locations/:lid" $ json $ object ["quantity" .= (100 :: Int)]

      -- Accounting
      get "/api/v1/accounting" $ json $ object ["accounts" .= ([] :: [Value])]
      get "/api/v1/accounting/accounts" $ json $ object ["items" .= ([] :: [Value])]
      get "/api/v1/accounting/accounts/:id" $ json $ object ["code" .= ("01" :: Text)]
      get "/api/v1/accounting/entries" $ json $ object ["items" .= ([] :: [Value])]

      -- Payroll
      get "/api/v1/payroll" $ json $ object ["employees" .= ([] :: [Value])]
      get "/api/v1/payroll/employees" $ json $ object ["items" .= ([] :: [Value])]
      get "/api/v1/payroll/employees/:id" $ json $ object ["name" .= ("Employee" :: Text)]
      get "/api/v1/payroll/salary/:eid/:period" $ json $ object ["gross" .= (50000.0 :: Double)]

      -- Jobs
      get "/api/v1/jobs" $ json $ object ["items" .= ([] :: [Value])]
      get "/api/v1/jobs/pending" $ json $ object ["count" .= (0 :: Int)]
      post "/api/v1/jobs" $ json $ object ["jobId" .= (1 :: Int64)]

      -- Reports
      get "/api/v1/reports" $ json $ object ["items" .= ([] :: [Value])]
      get "/api/v1/reports/:id" $ json $ object ["name" .= ("Report" :: Text)]
      post "/api/v1/reports" $ json $ object ["reportId" .= (1 :: Int64)]

healthStatus :: IO Text
healthStatus = pure "healthy"
