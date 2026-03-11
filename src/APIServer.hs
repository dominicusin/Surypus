{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

module APIServer
  ( ServerConfig(..)
  , runServer
  , healthStatus
  ) where

import Data.Aeson (FromJSON, ToJSON, Value(..), object, (.=))
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import GHC.Generics (Generic)
import Web.Scotty
import qualified Web.Scotty as Scotty

-- ============================================================================
-- CONFIG
-- ============================================================================

data ServerConfig = ServerConfig
  { scHost       :: String
  , scPort       :: Int
  , scLogRequests :: Bool
  , scJwtSecret  :: Text
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

createToken :: Text -> Int64 -> Text -> Text -> LoginResponse
createToken secret uid role name = LoginResponse
  { token = "eyJhbGciOiJIUzI1NiJ9." <> secret <> "." <> T.pack (show uid)
  , userId = uid
  , role = role
  , expiresAt = "2026-12-31T23:59:59Z"
  }

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
        secret = scJwtSecret cfg
    
    Scotty.scotty port $ do
      
      -- Root
      get "/" $ html "<h1>Surypus ERP/CRM v0.1.0</h1>"

      -- Health
      get "/api/v1/health" $ json $ object 
        [ "status" .= ("healthy" :: Text)
        , "version" .= ("0.1.0" :: Text)
        , "uptime" .= (100 :: Int)
        ]

      -- Auth
      post "/api/v1/auth/login" $ json $ createToken secret 1 "admin" "admin"

      post "/api/v1/auth/logout" $ json $ object ["success" .= True]

      get "/api/v1/auth/me" $ json $ object
        [ "userId" .= (1 :: Int64)
        , "username" .= ("admin" :: Text)
        , "role" .= ("admin" :: Text)
        ]

      -- Persons
      get "/api/v1/persons" $ json $ object 
        [ "items" .= ([] :: [Value])
        , "total" .= (5 :: Int)
        ]
      get "/api/v1/persons/:id" $ json $ object ["id" .= (1 :: Int64), "name" .= ("Test" :: Text)]
      post "/api/v1/persons" $ json $ object ["id" .= (1 :: Int64)]
      put "/api/v1/persons/:id" $ json $ object ["updated" .= True]
      delete "/api/v1/persons/:id" $ json $ object ["deleted" .= True]

      -- Goods
      get "/api/v1/goods" $ json $ object ["items" .= ([] :: [Value]), "total" .= (5 :: Int)]
      get "/api/v1/goods/:id" $ json $ object ["id" .= (1 :: Int64)]
      post "/api/v1/goods" $ json $ object ["id" .= (1 :: Int64)]
      put "/api/v1/goods/:id" $ json $ object ["updated" .= True]
      delete "/api/v1/goods/:id" $ json $ object ["deleted" .= True]

      -- Locations
      get "/api/v1/locations" $ json $ object ["items" .= ([] :: [Value]), "total" .= (5 :: Int)]
      get "/api/v1/locations/:id" $ json $ object ["id" .= (1 :: Int64)]
      post "/api/v1/locations" $ json $ object ["id" .= (1 :: Int64)]

      -- Bills
      get "/api/v1/bills" $ json $ object ["items" .= ([] :: [Value]), "total" .= (5 :: Int)]
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
      get "/api/v1/reports/templates" $ json $ object ["items" .= ([] :: [Value])]
      get "/api/v1/reports/:id" $ json $ object ["name" .= ("Report" :: Text)]
      post "/api/v1/reports" $ json $ object ["reportId" .= (1 :: Int64)]

healthStatus :: IO Text
healthStatus = pure "healthy"
