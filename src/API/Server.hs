{-# LANGUAGE OverloadedStrings #-}

-- | API Server - Simple Scotty server for Integration API
module API.Server
  ( runApp
  , IntegrationAPIConfig(..)
  ) where

import Web.Scotty
import qualified Web.Scotty.Trans as ST
import Data.Text.Lazy (Text)
import qualified Data.Text.Lazy as TL
import Data.Text (Text)
import qualified Data.Text as T
import Data.Aeson (Value, object, (.=))
import qualified API.Integration.REST as REST
import DAL.Database (Pool)
import Network.Wai.Middleware.RequestLogger (logStdoutDev)
import Network.Wai.Middleware.Cors (simpleCors)

-- | Integration API configuration
data IntegrationAPIConfig = IntegrationAPIConfig
  { iacPool :: Pool
  , iacJWTSecret :: Text
  , iacTokenExpiry :: Int
  , iacAllowedOrigins :: [Text]
  }

-- | Run the web application
runApp :: Pool -> Text -> Int -> IO ()
runApp pool jwtSecret port = do
  let config = REST.createIntegrationAPI pool jwtSecret 3600 ["*"]
  scottyOpts defaultOptions { settings = (defaultSettings { settingsPort = port }) } $ do
    middleware simpleCors
    middleware logStdoutDev
    
    -- Health check endpoint
    get "/health" $ text "OK"
    
    -- Accounting API endpoints
    get "/api/v1/accounting/ledgers" $ json $ object 
      [ "status" .= ("operational" :: Text)
      , "ledgers" .= ([] :: [Value])
      ]
    
    post "/api/v1/accounting/transactions" $ json $ object
      [ "status" .= ("success" :: Text)
      , "message" .= ("Transaction created (stub)" :: Text)
      ]
    
    get "/api/v1/accounting/balance/:accountId" $ do
      accountId <- param "accountId"
      json $ object
        [ "accountId" .= accountId
        , "balance" .= (0 :: Int)
        , "status" .= ("operational" :: Text)
        ]
    
    -- Inventory API endpoints
    get "/api/v1/inventory/goods" $ json $ object
      [ "status" .= ("operational" :: Text)
      , "goods" .= ([] :: [Value])
      ]
    
    post "/api/v1/inventory/goods" $ json $ object
      [ "status" .= ("success" :: Text)
      , "message" .= ("Goods created (stub)" :: Text)
      ]
    
    get "/api/v1/inventory/stock/:goodsId" $ do
      goodsId <- param "goodsId"
      json $ object
        [ "goodsId" .= goodsId
        , "quantity" .= (0 :: Int)
        , "status" .= ("operational" :: Text)
        ]
    
    post "/api/v1/inventory/stock/movement" $ json $ object
      [ "status" .= ("success" :: Text)
      , "message" .= ("Stock movement recorded (stub)" :: Text)
      ]
    
    -- Tax API endpoints
    get "/api/v1/tax/rates" $ json $ object
      [ "status" .= ("operational" :: Text)
      , "rates" .= ([] :: [Value])
      ]
    
    post "/api/v1/tax/calculate" $ json $ object
      [ "status" .= ("success" :: Text)
      , "taxAmount" .= (0 :: Int)
      , "message" .= ("Tax calculated (stub)" :: Text)
      ]
    
    -- Reports API endpoints
    get "/api/v1/reports/balance-sheet" $ json $ object
      [ "status" .= ("operational" :: Text)
      , "message" .= ("Balance sheet report (stub)" :: Text)
      ]
    
    get "/api/v1/reports/income-statement" $ json $ object
      [ "status" .= ("operational" :: Text)
      , "message" .= ("Income statement report (stub)" :: Text)
      ]
    
    get "/api/v1/reports/inventory" $ json $ object
      [ "status" .= ("operational" :: Text)
      , "message" .= ("Inventory report (stub)" :: Text)
      ]
    
    -- Integration API endpoints
    post "/api/v1/integrations/bank-statement/upload" $ do
      body <- body
      let request = REST.IntegrationRequest
            { REST.irPath = "/api/v1/integrations/bank-statement/upload"
            , REST.irMethod = "POST"
            , REST.irBody = Just body
            , REST.irHeaders = []
            }
      response <- liftIO $ REST.handleIntegrationRequest config "default-tenant" request
      json $ REST.irData response
    
    get "/api/v1/integrations/health" $ do
      let request = REST.IntegrationRequest
            { REST.irPath = "/api/v1/integrations/health"
            , REST.irMethod = "GET"
            , REST.irBody = Nothing
            , REST.irHeaders = []
            }
      response <- liftIO $ REST.handleIntegrationRequest config "default-tenant" request
      json $ REST.irData response
    
    get "/api/v1/integrations/status" $ do
      let request = REST.IntegrationRequest
            { REST.irPath = "/api/v1/integrations/status"
            , REST.irMethod = "GET"
            , REST.irBody = Nothing
            , REST.irHeaders = []
            }
      response <- liftIO $ REST.handleIntegrationRequest config "default-tenant" request
      json $ REST.irData response
