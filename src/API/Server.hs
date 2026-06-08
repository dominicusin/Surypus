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
import qualified Data.Text as T
import Data.Aeson (Value, object, (.=), decode)
import qualified API.Integration.REST as REST
import DAL.ORMPool (ConnectionPool)
import Network.Wai.Middleware.RequestLogger (logStdoutDev)
import Control.Monad.IO.Class (liftIO)
import qualified Data.ByteString.Lazy as LBS
-- import Network.Wai.Middleware.Cors (simpleCors)
import qualified Finance.Accounting as Acct
import qualified Inventory.Stock as Stock
import qualified Finance.Tax as Tax
import qualified Reports.Report as Report

-- | Integration API configuration
data IntegrationAPIConfig = IntegrationAPIConfig
  { iacPool :: ConnectionPool
  , iacJWTSecret :: Text
  , iacTokenExpiry :: Int
  , iacAllowedOrigins :: [Text]
  }

-- | Run the web application
runApp :: ConnectionPool -> Text -> Int -> IO ()
runApp pool jwtSecret port = do
  let config = REST.createIntegrationAPI pool (TL.toStrict jwtSecret) 3600 ["*"]
  scotty port $ do
    -- middleware simpleCors
    middleware logStdoutDev
    
    -- Health check endpoint
    get "/health" $ text "OK"
    
    -- Accounting API endpoints
    get "/api/v1/accounting/ledgers" . json $ object 
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
    get "/api/v1/inventory/goods" . json $ object
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
    get "/api/v1/tax/rates" . json $ object
      [ "status" .= ("operational" :: Text)
      , "rates" .= 
          [ object ["id" .= (1 :: Int), "name" .= ("Standard VAT" :: Text), "rate" .= (20 :: Int)]
          , object ["id" .= (2 :: Int), "name" .= ("Reduced VAT" :: Text), "rate" .= (10 :: Int)]
          , object ["id" .= (3 :: Int), "name" .= ("Zero VAT" :: Text), "rate" .= (0 :: Int)]
          ]
      ]
    
    post "/api/v1/tax/calculate" $ do
      -- In a full implementation, this would parse the request body and calculate tax
      -- For now, we'll demonstrate tax calculation using Finance.Tax
      let sampleRate = Tax.mkTaxRate 20
      case sampleRate of
        Nothing -> json $ object
          [ "status" .= ("error" :: Text)
          , "message" .= ("Invalid tax rate" :: Text)
          ]
        Just rate -> do
          let amount = 100
          let taxAmount = Tax.calcVAT amount rate
          json $ object
            [ "status" .= ("success" :: Text)
            , "amount" .= amount
            , "taxRate" .= Tax.unTaxRate rate
            , "taxAmount" .= taxAmount
            , "total" .= (amount + taxAmount)
            ]
    
    -- Reports API endpoints
    get "/api/v1/reports/balance-sheet" $ do
      -- In a full implementation, this would generate a balance sheet report
      -- For now, we'll demonstrate report types using Reports.Report
      let sampleReport = Report.Report
            { Report.rptId = 1
            , Report.rptCode = "BS-001"
            , Report.rptName = "Balance Sheet"
            , Report.rptType = Report.RTBalance
            , Report.rptQuery = "SELECT * FROM accounts"
            , Report.rptFlags = 0
            }
      json . object $
        [ "status" .= ("operational" :: Text)
        , "reportId" .= Report.rptId sampleReport
        , "reportCode" .= Report.rptCode sampleReport
        , "reportName" .= Report.rptName sampleReport
        , "reportType" .= show (Report.rptType sampleReport)
        ]
    
    get "/api/v1/reports/income-statement" $ do
      -- In a full implementation, this would generate an income statement report
      let sampleReport = Report.Report
            { Report.rptId = 2
            , Report.rptCode = "IS-001"
            , Report.rptName = "Income Statement"
            , Report.rptType = Report.RTJournal
            , Report.rptQuery = "SELECT * FROM transactions"
            , Report.rptFlags = 0
            }
      json . object $
        [ "status" .= ("operational" :: Text)
        , "reportId" .= Report.rptId sampleReport
        , "reportCode" .= Report.rptCode sampleReport
        , "reportName" .= Report.rptName sampleReport
        , "reportType" .= show (Report.rptType sampleReport)
        ]
    
    get "/api/v1/reports/inventory" $ do
      -- In a full implementation, this would generate an inventory report
      let sampleReport = Report.Report
            { Report.rptId = 3
            , Report.rptCode = "INV-001"
            , Report.rptName = "Inventory Report"
            , Report.rptType = Report.RTList
            , Report.rptQuery = "SELECT * FROM stock"
            , Report.rptFlags = 0
            }
      json . object $
        [ "status" .= ("operational" :: Text)
        , "reportId" .= Report.rptId sampleReport
        , "reportCode" .= Report.rptCode sampleReport
        , "reportName" .= Report.rptName sampleReport
        , "reportType" .= show (Report.rptType sampleReport)
        ]
    
    -- Integration API endpoints
    post "/api/v1/integrations/bank-statement/upload" $ do
      bodyBytes <- body
      let bodyVal = decode bodyBytes :: Maybe Value
      let request = REST.IntegrationRequest
            { REST.irPath = "/api/v1/integrations/bank-statement/upload"
            , REST.irMethod = "POST"
            , REST.irBody = bodyVal
            , REST.irHeaders = []
            , REST.irQueryParams = []
            }
      response <- liftIO $ REST.handleIntegrationRequest config "default-tenant" request
      json $ REST.irespBody response
     
    get "/api/v1/integrations/health" $ do
      let request = REST.IntegrationRequest
            { REST.irPath = "/api/v1/integrations/health"
            , REST.irMethod = "GET"
            , REST.irBody = Nothing
            , REST.irHeaders = []
            , REST.irQueryParams = []
            }
      response <- liftIO $ REST.handleIntegrationRequest config "default-tenant" request
      json $ REST.irespBody response
     
    get "/api/v1/integrations/status" $ do
      let request = REST.IntegrationRequest
            { REST.irPath = "/api/v1/integrations/status"
            , REST.irMethod = "GET"
            , REST.irBody = Nothing
            , REST.irHeaders = []
            , REST.irQueryParams = []
            }
      response <- liftIO $ REST.handleIntegrationRequest config "default-tenant" request
      json $ REST.irespBody response
