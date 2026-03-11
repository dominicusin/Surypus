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
      get "/" $ html "<h1>Surypus ERP/CRM</h1><p>Version 0.1.0</p>"

      get "/api/v1/health" $ json $ object 
        [ "status" .= ("healthy" :: Text), "version" .= ("0.1.0" :: Text), "uptime" .= (100 :: Int) ]

      post "/api/v1/auth/login" $ json $ object 
        [ "token" .= ("stub-token" :: Text), "userId" .= (1 :: Int64), "role" .= ("admin" :: Text) ]
      post "/api/v1/auth/logout" $ json $ object ["success" .= True]

      get "/api/v1/persons" $ json $ object ["items" .= ([] :: [Value]), "total" .= (0 :: Int), "page" .= (1 :: Int)]
      get "/api/v1/persons/:id" $ json $ object ["id" .= (1 :: Int64), "name" .= ("Test" :: Text)]
      post "/api/v1/persons" $ json $ object ["id" .= (1 :: Int64)]
      put "/api/v1/persons/:id" $ json $ object ["updated" .= True]
      delete "/api/v1/persons/:id" $ json $ object ["deleted" .= True]

      get "/api/v1/goods" $ json $ object ["items" .= ([] :: [Value]), "total" .= (0 :: Int)]
      get "/api/v1/goods/:id" $ json $ object ["id" .= (1 :: Int64), "name" .= ("Product" :: Text), "price" .= (100.0 :: Double)]
      post "/api/v1/goods" $ json $ object ["id" .= (1 :: Int64)]

      get "/api/v1/locations" $ json $ object ["items" .= ([] :: [Value]), "total" .= (0 :: Int)]
      get "/api/v1/locations/:id" $ json $ object ["id" .= (1 :: Int64), "name" .= ("Warehouse" :: Text)]

      get "/api/v1/bills" $ json $ object ["items" .= ([] :: [Value]), "total" .= (0 :: Int)]
      get "/api/v1/bills/:id" $ json $ object ["id" .= (1 :: Int64), "number" .= ("INV-001" :: Text), "total" .= (1000.0 :: Double)]
      post "/api/v1/bills" $ json $ object ["id" .= (1 :: Int64)]

      get "/api/v1/stock" $ json $ object ["items" .= ([] :: [Value]), "total" .= (0 :: Int)]
      get "/api/v1/stock/:goodsId/locations/:locId" $ json $ object ["quantity" .= (100 :: Int), "reserved" .= (10 :: Int)]

      get "/api/v1/accounting" $ json $ object ["accounts" .= ([] :: [Value])]
      get "/api/v1/accounting/accounts" $ json $ object ["items" .= ([] :: [Value])]
      get "/api/v1/accounting/accounts/:id" $ json $ object ["code" .= ("01" :: Text), "name" .= ("Cash" :: Text), "balance" .= (0.0 :: Double)]
      get "/api/v1/accounting/entries" $ json $ object ["items" .= ([] :: [Value])]

      get "/api/v1/payroll" $ json $ object ["employees" .= ([] :: [Value])]
      get "/api/v1/payroll/employees" $ json $ object ["items" .= ([] :: [Value])]
      get "/api/v1/payroll/employees/:id" $ json $ object ["name" .= ("Employee" :: Text), "salary" .= (50000.0 :: Double)]
      get "/api/v1/payroll/salary/:employeeId/:period" $ json $ object ["gross" .= (50000.0 :: Double), "net" .= (43500.0 :: Double), "tax" .= (6500.0 :: Double)]

      get "/api/v1/jobs" $ json $ object ["items" .= ([] :: [Value])]
      get "/api/v1/jobs/pending" $ json $ object ["count" .= (0 :: Int)]
      post "/api/v1/jobs" $ json $ object ["jobId" .= (1 :: Int64), "status" .= ("queued" :: Text)]

      get "/api/v1/reports" $ json $ object ["items" .= ([] :: [Value])]
      get "/api/v1/reports/:id" $ json $ object ["name" .= ("Report" :: Text), "status" .= ("ready" :: Text)]
      post "/api/v1/reports" $ json $ object ["reportId" .= (1 :: Int64)]

healthStatus :: IO Text
healthStatus = pure "healthy"
