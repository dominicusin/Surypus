-- ============================================================================
-- Surypus Event Sourcing Haskell Client
-- ============================================================================
-- High-level Haskell client for Surypus API
-- ============================================================================

{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE TypeApplications #-}

module SurypusClient
    ( SurypusClient(..)
    , ClientConfig(..)
    , defaultClientConfig
    , withClient
    , receiveStock
    , issueStock
    , getStockBalance
    , createBill
    , postBill
    , startSaga
    , getSagaStatus
    -- Re-exports
    , module SurypusClient.Types
    ) where

import Control.Exception (bracket, Exception, throwIO)
import Control.Monad (void)
import Data.Aeson (FromJSON, ToJSON, encode, eitherDecode)
import Data.ByteString (ByteString)
import qualified Data.ByteString.Char8 as BS
import qualified Data.ByteString.Lazy.Char8 as BL
import Data.Text (Text)
import qualified Data.Text as T
import Data.UUID (UUID, toText)
import GHC.Generics (Generic)
import Network.HTTP.Client
import Network.HTTP.Client.TLS (tlsManagerSettings)
import Network.HTTP.Types.Status (statusCode, statusMessage)

import SurypusClient.Types

-- ============================================================================
-- CLIENT CONFIGURATION
-- ============================================================================

data ClientConfig = ClientConfig
    { baseUrl     :: Text
    , apiKey      :: Maybe Text
    , tenantId    :: Maybe UUID
    , httpManager :: Manager
    }

-- | Default client configuration
defaultClientConfig :: Text -> IO ClientConfig
defaultClientConfig url = do
    mgr <- newManager tlsManagerSettings
    return $ ClientConfig
        { baseUrl = url
        , apiKey = Nothing
        , tenantId = Nothing
        , httpManager = mgr
        }

-- | Create client with API key
withApiKey :: ClientConfig -> Text -> ClientConfig
withApiKey cfg key = cfg { apiKey = Just key }

-- | Create client with tenant ID
withTenantId :: ClientConfig -> UUID -> ClientConfig
withTenantId cfg tid = cfg { tenantId = Just tid }

-- ============================================================================
-- CLIENT HANDLE
-- ============================================================================

newtype SurypusClient = SurypusClient
    { clientConfig :: ClientConfig
    }

-- | Bracket for safe client usage
withClient :: ClientConfig -> (SurypusClient -> IO a) -> IO a
withClient cfg = bracket (pure $ SurypusClient cfg) (const $ return ())

-- ============================================================================
-- API ERRORS
-- ============================================================================

data SurypusAPIError = SurypusAPIError
    { errorStatus  :: Int
    , errorMessage :: Text
    , errorBody    :: Maybe Text
    } deriving (Show, Eq, Generic, Exception)

throwAPIError :: Response a -> IO b
throwAPIError resp = throwIO $ SurypusAPIError
    { errorStatus = statusCode $ responseStatus resp
    , errorMessage = T.pack $ BS.unpack $ statusMessage $ responseStatus resp
    , errorBody = Nothing
    }

-- ============================================================================
-- HTTP HELPERS
-- ============================================================================

makeRequest :: (ToJSON a, FromJSON b) 
            => SurypusClient 
            -> Text           -- ^ Method
            -> Text           -- ^ Path
            -> Maybe a        -- ^ Body
            -> IO b
makeRequest (SurypusClient ClientConfig{..}) method path body = do
    let url = T.unpack $ baseUrl <> path
        req = defaultRequest
            { method = BS.pack $ T.unpack method
            , requestHeaders = [ ("Content-Type", "application/json") ]
                              ++ maybe [] (\k -> [("X-API-Key", T.encodeUtf8 k)]) apiKey
            }
    
    req' <- parseRequest url
    let req'' = req' { 
        method = BS.pack $ T.unpack method
        , requestHeaders = [ ("Content-Type", "application/json") ]
                           ++ maybe [] (\k -> [("X-API-Key", T.encodeUtf8 k)]) apiKey
                           ++ maybe [] (\t -> [("X-Tenant-Id", T.encodeUtf8 $ toText t)]) tenantId
        , requestBody = maybe "\"\"" (RequestBodyLBS . encode) body
        }
    
    resp <- httpLbs req'' httpManager
    
    case statusCode $ responseStatus resp of
        200 -> case eitherDecode $ responseBody resp of
            Left e -> throwIO $ SurypusAPIError 200 (T.pack e) Nothing
            Right r -> return r
        201 -> case eitherDecode $ responseBody resp of
            Left e -> throwIO $ SurypusAPIError 201 (T.pack e) Nothing
            Right r -> return r
        _   -> throwAPIError resp

get :: FromJSON b => SurypusClient -> Text -> IO b
get client path = makeRequest client "GET" path (Nothing :: Maybe ())

post :: (ToJSON a, FromJSON b) => SurypusClient -> Text -> a -> IO b
post client path body = makeRequest client "POST" path (Just body)

-- ============================================================================
-- INVENTORY API
-- ============================================================================

-- | Receive stock
receiveStock :: SurypusClient -> ReceiveStockRequest -> IO CommandResponse
receiveStock client req = post client "/inventory/receive" req

-- | Issue stock (FIFO)
issueStock :: SurypusClient -> IssueStockRequest -> IO IssueStockResponse
issueStock client req = post client "/inventory/issue" req

-- | Get stock balance
getStockBalance :: SurypusClient -> UUID -> UUID -> IO StockBalanceResponse
getStockBalance client goodsId locationId = 
    get client $ "/inventory/balance?goodsId=" <> toText goodsId <> "&locationId=" <> toText locationId

-- ============================================================================
-- BILL API
-- ============================================================================

-- | Create bill
createBill :: SurypusClient -> CreateBillRequest -> IO CommandResponse
createBill client req = post client "/bills" req

-- | Post bill
postBill :: SurypusClient -> UUID -> IO CommandResponse
postBill client billId = post client ("/bills/" <> toText billId <> "/post") ({} :: Maybe ())

-- ============================================================================
-- SAGA API
-- ============================================================================

-- | Start saga
startSaga :: SurypusClient -> StartSagaRequest -> IO StartSagaResponse
startSaga client req = post client "/sagas" req

-- | Get saga status
getSagaStatus :: SurypusClient -> UUID -> IO SagaStatusResponse
getSagaStatus client sagaId = get client $ "/sagas/" <> toText sagaId
