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
