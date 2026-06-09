-- | Role-Based Access Control (RBAC)
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
module Surypus.RBAC
  ( Permission,
    permissionToText,
    parsePermissionText,
    requirePermission,
    requirePermissionChecked,
    setPermissionChecker,
  )
where

import Control.Monad.IO.Class (MonadIO, liftIO)
import Data.IORef (IORef, newIORef, readIORef, writeIORef)
import Data.Int (Int64)
import Data.Text (Text)
import qualified Data.Text.Lazy as TL
import qualified Data.Text.Lazy.Encoding as LBS
import Servant (Handler, err403, errBody, throwError)
import System.IO.Unsafe (unsafePerformIO)

-- | Permission type
data Permission
  = PersonRead
  | PersonWrite
  | PersonDelete
  | GoodsRead
  | GoodsWrite
  | GoodsDelete
  | BillRead
  | BillWrite
  | BillDelete
  | BillPost
  | PaymentRead
  | PaymentWrite
  | PaymentDelete
  | LocationRead
  | LocationWrite
  | LocationDelete
  | StockRead
  | StockWrite
  | AccountingRead
  | AccountingWrite
  | PayrollRead
  | PayrollWrite
  | ReportsRead
  | ReportsWrite
  | UsersRead
  | UsersWrite
  | SettingsRead
  | SettingsWrite
  | AdminAccess
  | OrdersWrite
  | TaxesWrite
  | CurrenciesWrite
  | SalariesWrite
  deriving (Show, Eq, Enum, Bounded)

-- | Convert permission to text representation
permissionToText :: Permission -> Text
permissionToText = \case
  PersonRead -> "person:read"
  PersonWrite -> "person:write"
  PersonDelete -> "person:delete"
  GoodsRead -> "goods:read"
  GoodsWrite -> "goods:write"
  GoodsDelete -> "goods:delete"
  BillRead -> "bill:read"
  BillWrite -> "bill:write"
  BillDelete -> "bill:delete"
  BillPost -> "bill:post"
  PaymentRead -> "payment:read"
  PaymentWrite -> "payment:write"
  PaymentDelete -> "payment:delete"
  LocationRead -> "location:read"
  LocationWrite -> "location:write"
  LocationDelete -> "location:delete"
  StockRead -> "stock:read"
  StockWrite -> "stock:write"
  AccountingRead -> "accounting:read"
  AccountingWrite -> "accounting:write"
  PayrollRead -> "payroll:read"
  PayrollWrite -> "payroll:write"
  ReportsRead -> "reports:read"
  ReportsWrite -> "reports:write"
  UsersRead -> "users:read"
  UsersWrite -> "users:write"
  SettingsRead -> "settings:read"
  SettingsWrite -> "settings:write"
  AdminAccess -> "admin:access"
  OrdersWrite -> "orders:write"
  TaxesWrite -> "taxes:write"
  CurrenciesWrite -> "currencies:write"
  SalariesWrite -> "salaries:write"

-- | Parse permission from text representation
parsePermissionText :: Text -> Maybe Permission
parsePermissionText = \case
  "person:read" -> Just PersonRead
  "person:write" -> Just PersonWrite
  "person:delete" -> Just PersonDelete
  "goods:read" -> Just GoodsRead
  "goods:write" -> Just GoodsWrite
  "goods:delete" -> Just GoodsDelete
  "bill:read" -> Just BillRead
  "bill:write" -> Just BillWrite
  "bill:delete" -> Just BillDelete
  "bill:post" -> Just BillPost
  "payment:read" -> Just PaymentRead
  "payment:write" -> Just PaymentWrite
  "payment:delete" -> Just PaymentDelete
  "location:read" -> Just LocationRead
  "location:write" -> Just LocationWrite
  "location:delete" -> Just LocationDelete
  "stock:read" -> Just StockRead
  "stock:write" -> Just StockWrite
  "accounting:read" -> Just AccountingRead
  "accounting:write" -> Just AccountingWrite
  "payroll:read" -> Just PayrollRead
  "payroll:write" -> Just PayrollWrite
  "reports:read" -> Just ReportsRead
  "reports:write" -> Just ReportsWrite
  "users:read" -> Just UsersRead
  "users:write" -> Just UsersWrite
  "settings:read" -> Just SettingsRead
  "settings:write" -> Just SettingsWrite
  "admin:access" -> Just AdminAccess
  "orders:write" -> Just OrdersWrite
  "taxes:write" -> Just TaxesWrite
  "currencies:write" -> Just CurrenciesWrite
  "salaries:write" -> Just SalariesWrite
  _ -> Nothing

-- | Permission checker type: userId -> Permission -> IO (Either error success)
type PermissionChecker = Int64 -> Permission -> IO (Either Text ())

-- | Global permission checker reference.
-- In production, set during server startup to DAL-backed checker.
{-# NOINLINE permCheckerRef #-}
permCheckerRef :: IORef (Maybe PermissionChecker)
permCheckerRef = unsafePerformIO $ newIORef Nothing

setPermissionChecker :: PermissionChecker -> IO ()
setPermissionChecker checker = writeIORef permCheckerRef (Just checker)

-- | Require a permission (used in servant handlers)
requirePermission :: Int64 -> Permission -> IO (Either Text ())
requirePermission userId perm = do
  mChecker <- readIORef permCheckerRef
  case mChecker of
    Just checker -> checker userId perm
    Nothing -> pure $ Left "Permission checker not initialized"

-- | Check if user has admin status (bypass all permissions)
checkAdminStatus :: Int64 -> IO Bool
checkAdminStatus _ = pure False

-- | Require permission with explicit check - throws 403 if denied
-- This is the production version that should be used
requirePermissionChecked :: Int64 -> Permission -> Handler ()
requirePermissionChecked userId perm = do
  result <- liftIO $ requirePermission userId perm
  case result of
    Right () -> pure ()
    Left err -> throwError err403 {errBody = LBS.encodeUtf8 $ "Permission denied: " <> TL.fromStrict err}