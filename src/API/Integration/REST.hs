{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

-- | REST API endpoints for external integration access
-- Phase 20-4: REST API for External Use with JWT authentication
module API.Integration.REST
  ( IntegrationAPIConfig(..)
  , createIntegrationAPI
  , handleIntegrationRequest
  , validateIntegrationToken
  , checkIntegrationPermission
  ) where

import Data.Text (Text)
import qualified Data.Text as T
import Data.Aeson (ToJSON, FromJSON, Value, object, (.=))
import GHC.Generics (Generic)
import Data.Time (UTCTime)
import Data.Int (Int64)
import DAL.Database (Pool)
import qualified Surypus.JWT as JWT
import qualified Surypus.RBAC as RBAC

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
createIntegrationAPI config = return config

-- | Handle integration API request with authentication
handleIntegrationRequest :: IntegrationAPIConfig -> Text -> IntegrationRequest -> IO IntegrationResponse
handleIntegrationRequest config authToken request = do
  -- Validate token
  authResult <- validateIntegrationToken config authToken
  if not (arValid authResult)
    then return $ errorResponse 401 "Invalid authentication token"
    else do
      -- Check permissions based on request method
      let requiredPermission = getRequiredPermission (irMethod request)
      if not (checkIntegrationPermission (arPermissions authResult) requiredPermission)
        then return $ errorResponse 403 "Insufficient permissions"
        else do
          -- Process the request (stub implementation)
          processRequest config (arTenantId authResult) request

-- | Process authenticated integration request
processRequest :: IntegrationAPIConfig -> Text -> IntegrationRequest -> IO IntegrationResponse
processRequest config tenantId request = do
  -- Stub implementation - would route to actual handlers
  case irPath request of
    "/api/v1/integrations/bank-statement/upload" -> 
      return $ successResponse $ object ["message" .= ("Bank statement upload endpoint" :: Text)]
    "/api/v1/integrations/health" -> 
      return $ successResponse $ object ["message" .= ("Health status endpoint" :: Text)]
    "/api/v1/integrations/status" -> 
      return $ successResponse $ object ["message" .= ("Integration status endpoint" :: Text)]
    _ -> 
      return $ errorResponse 404 "Endpoint not found"

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
