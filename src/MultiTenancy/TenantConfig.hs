{-# LANGUAGE OverloadedStrings #-}
module MultiTenancy.TenantConfig where

import Data.Text (Text)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Data.Int (Int64)

-- | Tenant configuration
data TenantConfig = TenantConfig
  { tcTenantId :: Int64
  , tcName :: Text
  , tcDatabaseSchema :: Text
  , tcFeatures :: Map Text Bool
  , tcBranding :: TenantBranding
  } deriving (Eq, Show)

-- | Branding settings per tenant
data TenantBranding = TenantBranding
  { tbLogoUrl :: Maybe Text
  , tbPrimaryColor :: Text
  , tbCompanyName :: Text
  } deriving (Eq, Show)

-- | Load tenant config from database
loadTenantConfig :: Int64 -> IO (Maybe TenantConfig)
loadTenantConfig tenantId = do
  -- TODO: Implement database lookup
  return Nothing

-- | Get tenant schema name
tenantSchema :: TenantConfig -> Text
tenantSchema = tcDatabaseSchema
