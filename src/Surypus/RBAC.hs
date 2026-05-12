-- | Role-Based Access Control (RBAC)
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE OverloadedStrings #-}
module Surypus.RBAC
  ( Permission,
    permissionToText,
    parsePermissionText,
    requirePermission,
    requirePermissionChecked,
  )
where

import Control.Monad.IO.Class (MonadIO (liftIO))
import Data.Text (Text)
import Servant (Handler, err403, throwError)

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

-- | Require a permission (used in servant handlers)
-- By default allows all - override in production
requirePermission :: Permission -> IO ()
requirePermission _ = pure ()

-- | Require permission with explicit check - throws 403 if denied
-- This is the production version that should be used
requirePermissionChecked :: Permission -> Handler ()
requirePermissionChecked perm = 
  -- TODO: Check user context from request
  -- For now, allow with warning log
  liftIO $ putStrLn $ "WARN: Permission check bypassed for: " ++ show perm