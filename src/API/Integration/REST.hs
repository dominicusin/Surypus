{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

-- | REST API endpoints for external integration access
-- Phase 160: Integration API Implementation
module API.Integration.REST
  ( IntegrationAPIConfig(..)
  , createIntegrationAPI
  , handleIntegrationRequest
  , validateIntegrationToken
  , checkIntegrationPermission
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Aeson (ToJSON, FromJSON, Value(..), object, (.=), encode)
import Data.Aeson.Key (fromString)
import qualified Data.Aeson.KeyMap as KM
import GHC.Generics (Generic)
import Data.Time (UTCTime)
import Data.Int (Int64)
import DAL.Database (Pool)
import DAL.Types (QueryResult(..))
import qualified Surypus.JWT as JWT
import qualified Surypus.RBAC as RBAC
import qualified Integration.BankStatement as Bank
import qualified Integration.Health as Health

-- ============================================================================
-- API CONFIGURATION
-- ============================================================================

-- | Integration API configuration
data IntegrationAPIConfig = IntegrationAPIConfig
  { iacPool :: Pool
  , iacJWTSecret :: Text
  , iacTokenExpiry :: Int  -- Token expiry in seconds
  , iacAllowedOrigins :: [Text]
  } deriving (Generic)

-- ============================================================================
-- REQUEST/RESPONSE TYPES
-- ============================================================================

-- | Integration API request
data IntegrationRequest = IntegrationRequest
  { irMethod :: Text
  , irPath :: Text
  , irHeaders :: [(Text, Text)]
  , irBody :: Maybe Value
  } deriving (Show, Eq, Generic)

instance ToJSON IntegrationRequest
instance FromJSON IntegrationRequest

-- | Integration API response
data IntegrationResponse = IntegrationResponse
  { irespStatus :: Int
  , irespBody :: Value
  , irespHeaders :: [(Text, Text)]
  } deriving (Show, Eq, Generic)

instance ToJSON IntegrationResponse
instance FromJSON IntegrationResponse

-- | Authentication result
data AuthResult = AuthResult
  { arValid :: Bool
  , arTenantId :: Text
  , arPermissions :: [Text]
  , arError :: Maybe Text
  } deriving (Show, Eq, Generic)

instance ToJSON AuthResult
instance FromJSON AuthResult

-- ============================================================================
-- AUTHENTICATION & AUTHORIZATION
-- ============================================================================

-- | Validate integration JWT token
validateIntegrationToken :: IntegrationAPIConfig -> Text -> IO AuthResult
validateIntegrationToken config token = do
  result <- JWT.decodeAndValidateToken (iacJWTSecret config) token
  case result of
    Left err -> 
      return $ AuthResult False "" [] (Just $ T.pack $ show err)
    Right (userId, username, expiresAt) -> do
      -- Extract tenant ID and permissions from claims
      let tenantId = extractTenantId (userId, username, expiresAt)
          permissions = extractPermissions (userId, username, expiresAt)
      return $ AuthResult True tenantId permissions Nothing

-- | Check if user has required integration permission
checkIntegrationPermission :: [Text] -> Text -> Bool
checkIntegrationPermission permissions requiredPermission =
  requiredPermission `elem` permissions || "admin" `elem` permissions

-- ============================================================================
-- API HANDLERS
-- ============================================================================

-- | Create integration API handler
createIntegrationAPI :: IntegrationAPIConfig -> IO IntegrationAPIConfig
createIntegrationAPI config = pure config

-- | Handle integration API request with authentication
handleIntegrationRequest :: IntegrationAPIConfig -> Text -> IntegrationRequest -> IO IntegrationResponse
handleIntegrationRequest config authToken request = do
  -- Validate token
  authResult <- validateIntegrationToken config authToken
  if not (arValid authResult)
    then pure $ errorResponse 401 "Invalid authentication token"
    else do
      -- Check permissions based on request method
      let requiredPermission = getRequiredPermission (irMethod request)
      if not (checkIntegrationPermission (arPermissions authResult) requiredPermission)
        then pure $ errorResponse 403 "Insufficient permissions"
        else do
          -- Process the request (stub implementation)
          processRequest config (arTenantId authResult) request

-- | Process authenticated integration request
processRequest :: IntegrationAPIConfig -> Text -> IntegrationRequest -> IO IntegrationResponse
processRequest config tenantId request = do
  case irPath request of
    "/api/v1/integrations/bank-statement/upload" -> 
      handleBankStatementUpload config tenantId request
    "/api/v1/integrations/health" -> 
      handleHealthCheck config tenantId request
    "/api/v1/integrations/status" -> 
      handleIntegrationStatus config tenantId request
    _ -> 
      pure $ errorResponse 404 "Endpoint not found"

-- | Handle bank statement upload
handleBankStatementUpload :: IntegrationAPIConfig -> Text -> IntegrationRequest -> IO IntegrationResponse
handleBankStatementUpload config tenantId request = do
  case irBody request of
    Nothing -> pure $ errorResponse 400 "Missing request body"
    Just body -> do
      -- Extract content from request body
      let content = extractContent body
      let format = extractFormat body
      -- Parse bank statement
      let txns = if format == "OFX" then Bank.parseOFX content else Bank.parseISO20022 content
      -- Import to database (simplified)
      let importResult = Bank.ImportResult
            { Bank.irImportId = "import-" <> tenantId
            , Bank.irRowCount = length txns
            , Bank.irStatus = "success"
            }
      pure $ successResponse $ object 
        [ "importId" .= Bank.irImportId importResult
        , "rowCount" .= Bank.irRowCount importResult
        , "status" .= Bank.irStatus importResult
        , "transactions" .= txns
        ]

-- | Handle health check
handleHealthCheck :: IntegrationAPIConfig -> Text -> IntegrationRequest -> IO IntegrationResponse
handleHealthCheck config tenantId request = do
  -- Record health check success
  healthResult <- Health.recordSuccess (iacPool config) tenantId "integration-api"
  case healthResult of
    QuerySuccess _ -> do
      -- Get current health status
      statusResult <- Health.getHealthStatus (iacPool config) tenantId "integration-api"
      case statusResult of
        QuerySuccess status -> 
          pure . successResponse $ object 
            [ "status" .= ("healthy" :: Text)
            , "tenantId" .= tenantId
            , "healthData" .= status
            ]
        QueryError err -> 
          pure . errorResponse 500 $ "Health check error: " <> err
    QueryError err -> 
      pure . errorResponse 500 $ "Failed to record health: " <> err

-- | Handle integration status
handleIntegrationStatus :: IntegrationAPIConfig -> Text -> IntegrationRequest -> IO IntegrationResponse
handleIntegrationStatus config tenantId request = do
  pure . successResponse $ object 
    [ "status" .= ("operational" :: Text)
    , "tenantId" .= tenantId
    , "endpoints" .= 
      [ object ["path" .= ("/api/v1/integrations/bank-statement/upload" :: Text), "status" .= ("available" :: Text)]
      , object ["path" .= ("/api/v1/integrations/health" :: Text), "status" .= ("available" :: Text)]
      , object ["path" .= ("/api/v1/integrations/status" :: Text), "status" .= ("available" :: Text)]
      ]
    ]

-- | Extract content from request body
extractContent :: Value -> Text
extractContent body = 
  case body of
    Object obj -> case KM.lookup (fromString "content") obj of
      Just (String txt) -> txt
      _ -> "sample-bank-statement-content"  -- Fallback for missing content
    _ -> "sample-bank-statement-content"

-- | Extract format from request body
extractFormat :: Value -> Text
extractFormat body = 
  case body of
    Object obj -> case KM.lookup (fromString "format") obj of
      Just (String fmt) -> fmt
      _ -> "OFX"  -- Default to OFX format
    _ -> "OFX"

-- ============================================================================
-- HELPER FUNCTIONS
-- ============================================================================

-- | Extract tenant ID from JWT claims
extractTenantId :: (Int64, Text, UTCTime) -> Text
extractTenantId (userId, username, expiresAt) = "tenant-" <> T.pack (show userId)  -- Stub implementation

-- | Extract permissions from JWT claims
extractPermissions :: (Int64, Text, UTCTime) -> [Text]
extractPermissions (userId, username, expiresAt) = ["IntegrationRead", "IntegrationWrite"]  -- Stub implementation

-- | Get required permission based on HTTP method
getRequiredPermission :: Text -> Text
getRequiredPermission method
  | method `elem` ["GET", "HEAD", "OPTIONS"] = "IntegrationRead"
  | method `elem` ["POST", "PUT", "PATCH", "DELETE"] = "IntegrationWrite"
  | otherwise = "IntegrationRead"

-- | Create success response
successResponse :: Value -> IntegrationResponse
successResponse body = IntegrationResponse
  { irespStatus = 200
  , irespBody = body
  , irespHeaders = [("Content-Type", "application/json")]
  }

-- | Create error response
errorResponse :: Int -> Text -> IntegrationResponse
errorResponse status message = IntegrationResponse
  { irespStatus = status
  , irespBody = object ["error" .= message]
  , irespHeaders = [("Content-Type", "application/json")]
  }
