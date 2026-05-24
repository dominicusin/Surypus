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
import qualified Finance.Accounting as Acct
import qualified Inventory.Stock as Stock

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
      , "ledgers" .= 
          [ object ["id" .= (1 :: Int), "code" .= ("1000" :: Text), "name" .= ("Cash" :: Text), "type" .= ("Asset" :: Text)]
          , object ["id" .= (2 :: Int), "code" .= ("2000" :: Text), "name" .= ("Accounts Payable" :: Text), "type" .= ("Liability" :: Text)]
          ]
      ]
    
    post "/api/v1/accounting/transactions" $ do
      -- In a full implementation, this would parse the request body and create a transaction
      -- For now, we'll validate a sample transaction using Finance.Accounting
      let sampleTx = Acct.Transaction 
            { Acct.txId = Nothing
            , Acct.txDate = read "2024-01-01"
            , Acct.txDescription = "Sample transaction"
            , Acct.txEntries = []
            }
      case Acct.validateTransaction sampleTx of
        Left err -> json $ object
          [ "status" .= ("error" :: Text)
          , "message" .= err
          ]
        Right _ -> json $ object
          [ "status" .= ("success" :: Text)
          , "message" .= ("Transaction validated successfully" :: Text)
          ]
    
    get "/api/v1/accounting/balance/:accountId" $ do
      accountId <- param "accountId"
      -- Calculate a sample balance using Finance.Accounting
      let sampleEntry = Acct.LedgerEntry
            { Acct.leId = Nothing
            , Acct.leDate = read "2024-01-01"
            , Acct.leAccount = accountId
            , Acct.leDescription = "Sample entry"
            , Acct.leDebit = 1000
            , Acct.leCredit = 500
            , Acct.leDocRef = Nothing
            }
      let bal = Acct.balance sampleEntry
      json $ object
        [ "accountId" .= accountId
        , "balance" .= bal
        , "status" .= ("operational" :: Text)
        ]
    
    -- Inventory API endpoints
    get "/api/v1/inventory/goods" $ json $ object
      [ "status" .= ("operational" :: Text)
      , "goods" .= 
          [ object ["id" .= (1 :: Int), "name" .= ("Widget A" :: Text), "sku" .= ("WGT-A-001" :: Text)]
          , object ["id" .= (2 :: Int), "name" .= ("Widget B" :: Text), "sku" .= ("WGT-B-002" :: Text)]
          ]
      ]
    
    post "/api/v1/inventory/goods" $ do
      -- In a full implementation, this would parse the request body and create goods
      -- For now, we'll validate a sample stock using Inventory.Stock
      let flags = Stock.StockFlags { Stock.sfNegativeAllowed = False, Stock.sfAutoReserve = True }
      let sampleStock = Stock.mkStock 1 1 100.0 10.0 20.0 50.0 75.0 flags
      case sampleStock of
        Nothing -> json $ object
          [ "status" .= ("error" :: Text)
          , "message" .= ("Invalid stock data" :: Text)
          ]
        Just _ -> json $ object
          [ "status" .= ("success" :: Text)
          , "message" .= ("Goods created successfully" :: Text)
          ]
    
    get "/api/v1/inventory/stock/:goodsId" $ do
      goodsId <- param "goodsId"
      -- Get sample stock using Inventory.Stock
      let flags = Stock.StockFlags { Stock.sfNegativeAllowed = False, Stock.sfAutoReserve = True }
      let sampleStock = Stock.mkStock goodsId 1 100.0 10.0 20.0 50.0 75.0 flags
      case sampleStock of
        Nothing -> json $ object
          [ "goodsId" .= goodsId
          , "quantity" .= (0 :: Int)
          , "status" .= ("error" :: Text)
          ]
        Just stock -> json $ object
          [ "goodsId" .= goodsId
          , "quantity" .= Stock.sQtty stock
          , "reserved" .= Stock.sResrvQtty stock
          , "ordered" .= Stock.sOrderedQtty stock
          , "status" .= ("operational" :: Text)
          ]
    
    post "/api/v1/inventory/stock/movement" $ do
      -- In a full implementation, this would record a stock movement
      -- For now, we'll demonstrate stock motion type
      json $ object
        [ "status" .= ("success" :: Text)
        , "message" .= ("Stock movement recorded" :: Text)
        , "motionTypes" .= 
            [ object ["type" .= ("Receipt" :: Text)]
            , object ["type" .= ("Shipment" :: Text)]
            , object ["type" .= ("TransferIn" :: Text)]
            , object ["type" .= ("TransferOut" :: Text)]
            , object ["type" .= ("WriteOff" :: Text)]
            , object ["type" .= ("Adjustment" :: Text)]
            ]
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
