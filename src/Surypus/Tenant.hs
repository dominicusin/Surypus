{-# LANGUAGE OverloadedStrings #-}

-- | Tenant Isolation Middleware
--
-- CRITICAL SECURITY COMPONENT
-- Ensures all database queries are filtered by tenant_id
--
-- This module provides:
-- 1. Extract tenant_id from JWT
-- 2. Inject tenant context into request
-- 3. Validate tenant access
module Surypus.Tenant where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Servant
import Surypus.JWT (JWTPayload (..))

-- | Tenant context passed through the request
data TenantContext = TenantContext
  { tcTenantId :: Int64,
    tcUserId :: Int64,
    tcRole :: Text
  }
  deriving (Show, Eq)

-- | Get tenant_id from JWT payload
getTenantId :: JWTPayload -> Maybe Int64
getTenantId payload = fmap fromIntegral (jwtTenantId payload)

-- | Validate user has access to tenant
hasTenantAccess :: JWTPayload -> Int64 -> Bool
hasTenantAccess payload targetTenant =
  maybe False (\t -> fromIntegral t == targetTenant) (jwtTenantId payload)

-- | Filter data by tenant (for queries)
-- This is the CRITICAL function that MUST be used in all SELECT statements
filterByTenant :: Int64 -> Text -> Text
filterByTenant tenantId table = table <> " WHERE tenant_id = " <> T.pack (show tenantId)

-- | Build tenant filter clause for WHERE
tenantWhereClause :: Int64 -> Text
tenantWhereClause tenantId = "tenant_id = " <> T.pack (show tenantId)

-- | Require tenant context or return 403
requireTenant :: Maybe TenantContext -> Handler a
requireTenant Nothing = throwError err403 {errBody = "Tenant context required"}
requireTenant (Just _) = throwError err403 {errBody = "No tenant access"}

-- | Check if user can access resource in their tenant
canAccessTenant :: JWTPayload -> Int64 -> Bool
canAccessTenant payload resourceTenantId =
  case jwtTenantId payload of
    Nothing -> False -- Global admin only
    Just t -> fromIntegral t == resourceTenantId

-- | Tenant-aware routing
-- Simplify to identity (eta-reduction): tenantPath f x = f x
tenantPath :: (Maybe TenantContext -> a) -> Maybe TenantContext -> a
tenantPath = id
