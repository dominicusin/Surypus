{-# LANGUAGE OverloadedStrings #-}
module MultiTenancy.TenantConfig
  ( TenantConfig(..)
  , TenantBranding(..)
  , loadTenantConfig
  , tenantSchema
  , defaultTenant
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import Data.Map.Strict (Map)
import qualified Data.Map.Strict as Map
import Database.Persist.Postgresql (ConnectionPool)

data TenantConfig = TenantConfig
  { tcTenantId :: !Int64
  , tcName :: !Text
  , tcDatabaseSchema :: !Text
  , tcFeatures :: !(Map Text Bool)
  , tcBranding :: !TenantBranding
  } deriving (Eq, Show)

data TenantBranding = TenantBranding
  { tbLogoUrl :: !(Maybe Text)
  , tbPrimaryColor :: !Text
  , tbCompanyName :: !Text
  } deriving (Eq, Show)

defaultTenant :: TenantConfig
defaultTenant = TenantConfig
  { tcTenantId = 0
  , tcName = "Default Tenant"
  , tcDatabaseSchema = "public"
  , tcFeatures = Map.empty
  , tcBranding = TenantBranding
      { tbLogoUrl = Nothing
      , tbPrimaryColor = "#1890ff"
      , tbCompanyName = "Default Tenant"
      }
  }

loadTenantConfig :: ConnectionPool -> Int64 -> IO (Maybe TenantConfig)
loadTenantConfig pool tenantId = do
  -- TODO: Implement DB-backed tenant config lookup
  -- Requires proper RawSql result typing
  pure Nothing

tenantSchema :: TenantConfig -> Text
tenantSchema = tcDatabaseSchema
