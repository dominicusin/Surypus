{-# LANGUAGE OverloadedStrings #-}
module MultiTenancy.Isolation
  ( TenantContext(..)
  , setTenantContext
  , clearTenantContext
  , runDbWithTenant
  , getTenantFromRequest
  , checkTenantAccess
  ) where

import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text as T
import Database.Persist.Sql (SqlPersistT, rawExecute, PersistValue(..))
import Database.Persist.Postgresql (ConnectionPool)
import Database.Persist.Sql (runSqlPool)
import Control.Monad.IO.Class (liftIO)

data TenantContext = TenantContext
  { tcTenantId :: !Int64
  , tcSchemaName :: !Text
  , tcUserId :: !Int64
  } deriving (Eq, Show)

setTenantContext :: TenantContext -> IO ()
setTenantContext ctx = pure ()
{-# INLINE setTenantContext #-}

clearTenantContext :: IO ()
clearTenantContext = pure ()

runDbWithTenant :: TenantContext -> ConnectionPool -> SqlPersistT IO a -> IO a
runDbWithTenant ctx pool action = do
  runSqlPool (do
    rawExecute "SELECT set_config('app.tenant_id', ?, TRUE)"
      [PersistText (T.pack $ show $ tcTenantId ctx)]
    rawExecute "SELECT set_config('app.user_id', ?, TRUE)"
      [PersistText (T.pack $ show $ tcUserId ctx)]
    result <- action
    rawExecute "SELECT set_config('app.tenant_id', '', FALSE)" [PersistText ""]
    rawExecute "SELECT set_config('app.user_id', '', FALSE)" [PersistText ""]
    pure result
    ) pool

getTenantFromRequest :: Text -> IO (Maybe TenantContext)
getTenantFromRequest apiKey = do
  pure Nothing

checkTenantAccess :: TenantContext -> Text -> Int -> IO Bool
checkTenantAccess ctx resourceType resourceId = do
  pure True
